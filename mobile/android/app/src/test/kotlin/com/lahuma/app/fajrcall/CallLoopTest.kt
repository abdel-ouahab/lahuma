package com.lahuma.app.fajrcall

import com.lahuma.app.fajrcall.CallLoop.Status
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Virtual time: [advance] runs every timer that falls due, in order. */
private class FakeClock : CallLoop.LoopTimer {
    var now = 0L
    private data class Task(val at: Long, val seq: Int, val action: () -> Unit, var cancelled: Boolean = false)
    private val tasks = mutableListOf<Task>()
    private var seq = 0

    override fun schedule(delayMs: Long, action: () -> Unit): CallLoop.Cancellable {
        val task = Task(now + delayMs, seq++, action)
        tasks += task
        return object : CallLoop.Cancellable {
            override fun cancel() { task.cancelled = true }
        }
    }

    fun advance(ms: Long) {
        val target = now + ms
        while (true) {
            val due = tasks.filter { !it.cancelled && it.at <= target }
                .minWithOrNull(compareBy({ it.at }, { it.seq })) ?: break
            tasks.remove(due)
            now = due.at
            due.action()
        }
        now = target
    }
}

/**
 * A scripted phone: each placed call goes off-hook at once; the test then
 * decides how it ends. Hang-ups end the call (IDLE) unless [refuseHangUp].
 */
private class FakeDialer(val clock: FakeClock) : CallLoop.Dialer {
    lateinit var loop: CallLoop
    val placed = mutableListOf<String>()
    var hangUps = 0
    var failNumbers = setOf<String>()
    var refuseHangUp = false
    var active = false

    override fun place(contact: CallLoop.Contact): Boolean {
        if (contact.phone in failNumbers) return false
        placed += contact.name
        active = true
        clock.schedule(500) { if (active) loop.onCallActive() }
        return true
    }

    override fun hangUp(): Boolean {
        hangUps++
        if (refuseHangUp) return false
        if (active) {
            active = false
            clock.schedule(200) { loop.onCallIdle() }
        }
        return true
    }

    /** The other side picks up / declines: the call ends now. */
    fun remoteEnds(answered: Boolean? = null) {
        active = false
        loop.onCallIdle(answered)
    }
}

class CallLoopTest {
    private val mum = CallLoop.Contact("1", "Mum", "+213551")
    private val dad = CallLoop.Contact("2", "Dad", "+213661")
    private val ali = CallLoop.Contact("3", "Ali", "+33612")

    private val clock = FakeClock()
    private val dialer = FakeDialer(clock)
    private var finished: List<CallLoop.Attempt>? = null
    private var stoppedByUser = false
    private val calling = mutableListOf<String>()

    private fun config(
        contacts: List<CallLoop.Contact> = listOf(mum, dad, ali),
        ring: Int = 20,
        wait: Int = 30,
        gap: Int = 3,
        stopFirst: Boolean = false,
        retry: Boolean = false,
        maxRetries: Int = 1,
        repeat: Boolean = false,
        loops: Int = 1,
        autoHangUp: Boolean = true,
    ) = CallLoop.LoopConfig(contacts, ring, wait, gap, stopFirst, retry, maxRetries, repeat, loops, autoHangUp)

    private fun loop(cfg: CallLoop.LoopConfig): CallLoop {
        val l = CallLoop(cfg, dialer, clock, { clock.now }, object : CallLoop.Listener {
            override fun onCalling(contact: CallLoop.Contact, attemptNo: Int) {
                calling += "${contact.name}#$attemptNo"
            }
            override fun onWaiting() {}
            override fun onFinished(attempts: List<CallLoop.Attempt>, stoppedByUser: Boolean) {
                finished = attempts
                this@CallLoopTest.stoppedByUser = stoppedByUser
            }
        })
        dialer.loop = l
        return l
    }

    /** Lets every call ring out to the ring timeout, then the gap. */
    private fun ringOutAll(rounds: Int = 10) = repeat(rounds * 10) { clock.advance(5_000) }

    @Test
    fun callsEveryoneInOrderAndHangsUpAtTheRingTimeout() {
        val l = loop(config())
        l.start()
        ringOutAll()
        assertEquals(listOf("Mum", "Dad", "Ali"), dialer.placed)
        assertEquals(3, dialer.hangUps)
        val results = finished!!
        assertEquals(listOf(Status.NO_ANSWER, Status.NO_ANSWER, Status.NO_ANSWER), results.map { it.status })
        // Rang for the 20 s ring time (+ the fake 200 ms to go idle).
        assertEquals(20_200L, results[0].endedAt - results[0].startedAt)
        assertTrue(l.isDone)
    }

    @Test
    fun waitsTheGapBetweenNumbers() {
        val l = loop(config(gap = 3))
        l.start()
        clock.advance(20_200) // Mum rings out
        assertEquals(listOf("Mum"), dialer.placed)
        clock.advance(2_900)
        assertEquals(listOf("Mum"), dialer.placed)
        clock.advance(100)
        assertEquals(listOf("Mum", "Dad"), dialer.placed)
    }

    @Test
    fun aCallEndedByTheOtherSideIsCalledAndWaitsAfterAnswer() {
        val l = loop(config(wait = 30))
        l.start()
        clock.advance(8_000)
        dialer.remoteEnds()
        assertEquals(Status.CALLED, l.results.single().status)
        clock.advance(29_000)
        assertEquals(listOf("Mum"), dialer.placed)
        clock.advance(1_000)
        assertEquals(listOf("Mum", "Dad"), dialer.placed)
    }

    @Test
    fun callLogClassificationWins() {
        val l = loop(config(contacts = listOf(mum, dad)))
        l.start()
        clock.advance(5_000)
        dialer.remoteEnds(answered = true)
        clock.advance(30_000)
        clock.advance(5_000)
        dialer.remoteEnds(answered = false)
        assertEquals(listOf(Status.ANSWERED, Status.NO_ANSWER), finished!!.map { it.status })
    }

    @Test
    fun stopsAfterTheFirstAnswer() {
        val l = loop(config(stopFirst = true))
        l.start()
        clock.advance(20_200) // Mum: no answer
        clock.advance(3_000)
        clock.advance(4_000)
        dialer.remoteEnds() // Dad picks up
        assertTrue(l.isDone)
        assertEquals(listOf("Mum", "Dad"), dialer.placed)
        assertEquals(listOf(Status.NO_ANSWER, Status.CALLED), finished!!.map { it.status })
    }

    @Test
    fun retriesOnlyThoseNotReached() {
        val l = loop(config(retry = true, maxRetries = 2))
        l.start()
        clock.advance(20_200) // Mum: no answer
        clock.advance(3_000)
        clock.advance(4_000)
        dialer.remoteEnds() // Dad answers
        ringOutAll() // everyone else rings out
        assertEquals(listOf("Mum", "Dad", "Ali", "Mum", "Ali", "Mum", "Ali"), dialer.placed)
        assertEquals(listOf("Mum#1", "Dad#1", "Ali#1", "Mum#2", "Ali#2", "Mum#3", "Ali#3"), calling)
    }

    @Test
    fun noRetryWhenTurnedOff() {
        val l = loop(config(retry = false))
        l.start()
        ringOutAll()
        assertEquals(3, dialer.placed.size)
    }

    @Test
    fun repeatsTheWholeLoopForPeopleNotReached() {
        val l = loop(config(contacts = listOf(mum, dad), retry = true, maxRetries = 1, repeat = true, loops = 1))
        l.start()
        ringOutAll()
        // First pass, one retry, then one more round.
        assertEquals(listOf("Mum", "Dad", "Mum", "Dad", "Mum", "Dad"), dialer.placed)
        assertEquals(listOf(1, 1, 2, 2, 3, 3), finished!!.map { it.attemptNo })
    }

    @Test
    fun stopActionHangsUpAndFinishes() {
        val l = loop(config())
        l.start()
        clock.advance(5_000)
        l.stop()
        assertTrue(l.isDone)
        assertTrue(stoppedByUser)
        assertEquals(1, dialer.hangUps)
        ringOutAll()
        assertEquals(listOf("Mum"), dialer.placed)
    }

    @Test
    fun aNumberThatCannotBeDialledFailsAndTheLoopMovesOn() {
        dialer.failNumbers = setOf(mum.phone)
        val l = loop(config(contacts = listOf(mum, dad)))
        l.start()
        assertEquals(Status.FAILED, l.results.single().status)
        clock.advance(3_000)
        assertEquals(listOf("Dad"), dialer.placed)
    }

    @Test
    fun aCallThatNeverGoesOffHookFails() {
        val l = loop(config(contacts = listOf(mum)))
        l.start()
        dialer.active = false // the off-hook event never comes
        clock.advance(CallLoop.DIAL_CHECK_MS)
        assertEquals(Status.FAILED, finished!!.single().status)
    }

    @Test
    fun theListenerReplayedIdleIsIgnored() {
        val l = loop(config(contacts = listOf(mum)))
        l.start()
        l.onCallIdle() // replayed at registration, 0 ms after dialling
        assertFalse(l.isDone)
        clock.advance(20_200)
        assertEquals(Status.NO_ANSWER, finished!!.single().status)
    }

    @Test
    fun aRefusedHangUpWaitsForTheNetworkThenMovesOn() {
        dialer.refuseHangUp = true
        val l = loop(config(contacts = listOf(mum, dad)))
        l.start()
        clock.advance(20_000)
        assertEquals(1, dialer.hangUps)
        clock.advance(CallLoop.HANG_UP_GRACE_MS)
        assertEquals(Status.NO_ANSWER, l.results.single().status)
        clock.advance(3_000)
        assertEquals(listOf("Mum", "Dad"), dialer.placed)
    }

    @Test
    fun withAutoHangUpOffTheCallRunsUntilTheOtherSideEndsIt() {
        val l = loop(config(contacts = listOf(mum, dad), ring = 20, autoHangUp = false))
        l.start()
        clock.advance(90_000) // well past the 20 s duration
        assertEquals(0, dialer.hangUps)
        assertTrue(l.results.isEmpty())
        dialer.remoteEnds()
        assertEquals(Status.CALLED, l.results.single().status)
    }

    @Test
    fun anEmptyListFinishesAtOnce() {
        val l = loop(config(contacts = emptyList()))
        l.start()
        assertTrue(l.isDone)
        assertTrue(finished!!.isEmpty())
    }
}
