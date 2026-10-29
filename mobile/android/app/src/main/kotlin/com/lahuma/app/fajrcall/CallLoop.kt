package com.lahuma.app.fajrcall

/**
 * The Fajr Call loop as a pure state machine: no Android types, so it is
 * unit-tested with a fake dialer and a fake clock (see CallLoopTest).
 *
 * The service feeds it telephony events ([onCallActive], [onCallIdle]) and
 * timer callbacks; it decides who to call next, when to hang up and how each
 * call is classified.
 *
 * Classification (Android cannot report when an outgoing call is answered):
 * - with call-log access, the caller passes `answered` to [onCallIdle]
 *   (call-log duration > 0) → ANSWERED or NO_ANSWER;
 * - without it, a call that rang for the whole ring time and was hung up by
 *   the app → NO_ANSWER; one that ended earlier (the other side answered or
 *   declined, or the network ended it) → CALLED;
 * - a call that could not be placed, or never went off-hook → FAILED.
 */
class CallLoop(
    private val config: LoopConfig,
    private val dialer: Dialer,
    private val timer: LoopTimer,
    private val clock: () -> Long,
    private val listener: Listener,
) {
    data class Contact(val id: String, val name: String, val phone: String)

    data class LoopConfig(
        val contacts: List<Contact>,
        val ringTimeoutSec: Int,
        val waitAfterAnswerSec: Int,
        val gapBetweenSec: Int,
        val stopAfterFirstAnswer: Boolean,
        val retryOnNoAnswer: Boolean,
        val maxRetries: Int,
        val repeatWholeLoop: Boolean,
        val loopRepeats: Int,
        /** False: never hang up; the other side or the network ends the call. */
        val autoHangUp: Boolean = true,
    )

    enum class Status { ANSWERED, NO_ANSWER, FAILED, CALLED }

    data class Attempt(
        val contact: Contact,
        val startedAt: Long,
        val endedAt: Long,
        val status: Status,
        val attemptNo: Int,
    )

    interface Dialer {
        /** Places the call; false if it could not be placed at all. */
        fun place(contact: Contact): Boolean

        /** Hangs up the current call; false if the platform refused. */
        fun hangUp(): Boolean
    }

    interface Cancellable {
        fun cancel()
    }

    interface LoopTimer {
        fun schedule(delayMs: Long, action: () -> Unit): Cancellable
    }

    interface Listener {
        fun onCalling(contact: Contact, attemptNo: Int)
        fun onWaiting()
        fun onFinished(attempts: List<Attempt>, stoppedByUser: Boolean)
    }

    private enum class Phase { IDLE, DIALING, RINGING, HANGING_UP, WAITING, DONE }

    private var phase = Phase.IDLE
    private val queue = ArrayDeque<Pair<Contact, Int>>()
    private val attempts = mutableListOf<Attempt>()
    private var current: Contact? = null
    private var currentAttemptNo = 0
    private var startedAt = 0L
    private var hungUpByUs = false
    private var pendingTimer: Cancellable? = null
    private var dialCheck: Cancellable? = null
    private var retriesDone = 0
    private var loopsDone = 0

    val isDone get() = phase == Phase.DONE
    val results: List<Attempt> get() = attempts.toList()

    fun start() {
        check(phase == Phase.IDLE) { "already started" }
        if (config.contacts.isEmpty()) return finish(stopped = false)
        config.contacts.forEach { queue.addLast(it to 1) }
        next()
    }

    /** The user tapped Stop. */
    fun stop() {
        if (phase == Phase.DONE) return
        pendingTimer?.cancel()
        dialCheck?.cancel()
        if (phase == Phase.DIALING || phase == Phase.RINGING || phase == Phase.HANGING_UP) {
            dialer.hangUp()
            record(Status.CALLED)
        }
        finish(stopped = true)
    }

    /** Telephony reports OFFHOOK for our outgoing call. */
    fun onCallActive() {
        if (phase != Phase.DIALING) return
        dialCheck?.cancel()
        phase = Phase.RINGING
    }

    private fun failDial() {
        pendingTimer?.cancel()
        dialCheck?.cancel()
        record(Status.FAILED)
        afterCall(Status.FAILED)
    }

    /**
     * Telephony reports IDLE: the call is over. [answered] comes from the
     * call log when available, null otherwise.
     */
    fun onCallIdle(answered: Boolean? = null) {
        when (phase) {
            Phase.DIALING -> {
                // Registering a call-state listener replays the current
                // state (IDLE) right away; only a later IDLE means the call
                // failed before going off-hook.
                if (clock() - startedAt < STALE_IDLE_MS) return
                failDial()
            }
            Phase.RINGING, Phase.HANGING_UP -> {
                pendingTimer?.cancel()
                val status = when (answered) {
                    true -> Status.ANSWERED
                    false -> Status.NO_ANSWER
                    null -> if (hungUpByUs) Status.NO_ANSWER else Status.CALLED
                }
                record(status)
                afterCall(status)
            }
            else -> Unit
        }
    }

    private fun next() {
        if (phase == Phase.DONE) return
        val item = queue.removeFirstOrNull() ?: return endOfPass()
        val (contact, attemptNo) = item
        current = contact
        currentAttemptNo = attemptNo
        startedAt = clock()
        hungUpByUs = false
        listener.onCalling(contact, attemptNo)
        phase = Phase.DIALING
        if (!dialer.place(contact)) {
            record(Status.FAILED)
            afterCall(Status.FAILED)
            return
        }
        // Ends after ringTimeoutSec, counted from dialling, unless the user
        // turned automatic hang-up off.
        if (config.autoHangUp) {
            pendingTimer = timer.schedule(config.ringTimeoutSec * 1000L) { onRingTimeout() }
        }
        // A call that never goes off-hook did not go through.
        dialCheck = timer.schedule(DIAL_CHECK_MS) { if (phase == Phase.DIALING) failDial() }
    }

    private fun onRingTimeout() {
        when (phase) {
            Phase.RINGING -> {
                hungUpByUs = true
                phase = Phase.HANGING_UP
                dialer.hangUp()
                // If the platform would not hang up, the network ends the call
                // eventually; don't wait for it forever.
                pendingTimer = timer.schedule(HANG_UP_GRACE_MS) {
                    if (phase == Phase.HANGING_UP) onCallIdle(null)
                }
            }
            else -> Unit
        }
    }

    private fun record(status: Status) {
        val contact = current ?: return
        attempts += Attempt(contact, startedAt, clock(), status, currentAttemptNo)
        current = null
    }

    private fun reached(status: Status) =
        status == Status.ANSWERED || status == Status.CALLED

    private fun afterCall(status: Status) {
        if (config.stopAfterFirstAnswer && reached(status)) return finish(stopped = false)
        val delaySec = if (reached(status)) config.waitAfterAnswerSec else config.gapBetweenSec
        if (queue.isEmpty() && !hasMorePasses()) return finish(stopped = false)
        phase = Phase.WAITING
        listener.onWaiting()
        pendingTimer = timer.schedule(delaySec * 1000L) { next() }
    }

    /** People not reached yet: no ANSWERED / CALLED attempt. */
    private fun unreached(): List<Contact> {
        val reachedIds = attempts.filter { reached(it.status) }.map { it.contact.id }.toSet()
        return config.contacts.filter { it.id !in reachedIds }
    }

    private fun attemptsOf(contact: Contact) = attempts.count { it.contact.id == contact.id }

    private fun hasMorePasses(): Boolean {
        if (unreached().isEmpty()) return false
        val retry = config.retryOnNoAnswer && retriesDone < config.maxRetries
        val loop = config.repeatWholeLoop && loopsDone < config.loopRepeats
        return retry || loop
    }

    private fun endOfPass() {
        val pending = unreached()
        when {
            pending.isEmpty() -> finish(stopped = false)
            config.retryOnNoAnswer && retriesDone < config.maxRetries -> {
                retriesDone++
                pending.forEach { queue.addLast(it to attemptsOf(it) + 1) }
                next()
            }
            config.repeatWholeLoop && loopsDone < config.loopRepeats -> {
                // Another round for everyone not reached yet. Retries are
                // not granted again, to keep 4 a.m. calls to a minimum.
                loopsDone++
                pending.forEach { queue.addLast(it to attemptsOf(it) + 1) }
                next()
            }
            else -> finish(stopped = false)
        }
    }

    private fun finish(stopped: Boolean) {
        if (phase == Phase.DONE) return
        pendingTimer?.cancel()
        dialCheck?.cancel()
        phase = Phase.DONE
        listener.onFinished(attempts.toList(), stopped)
    }

    companion object {
        /** After a refused hang-up, how long to wait for the network. */
        const val HANG_UP_GRACE_MS = 45_000L

        /** No OFFHOOK within this time after dialling → FAILED. */
        const val DIAL_CHECK_MS = 8_000L

        /** IDLE this soon after dialling is the listener's replay. */
        const val STALE_IDLE_MS = 1_500L
    }
}
