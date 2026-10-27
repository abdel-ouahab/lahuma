package com.lahuma.app.fajrcall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FajrAlarmsTest {
    private val day = 24L * 60 * 60 * 1000

    @Test
    fun picksTheFirstPrecomputedTimeAfterNow() {
        val times = listOf(1_000L, 2_000L, 3_000L)
        assertEquals(2_000L to false, FajrAlarms.nextFireTime(times, 1_000L))
    }

    @Test
    fun fallsBackToLastPlusWholeDaysAndFlagsARefresh() {
        val times = listOf(10_000L, 10_000L + day)
        val now = 10_000L + day + 5
        assertEquals(10_000L + 2 * day to true, FajrAlarms.nextFireTime(times, now))
        assertEquals(10_000L + 4 * day to true, FajrAlarms.nextFireTime(times, now + 2 * day))
    }

    @Test
    fun nothingWithoutTimes() {
        assertNull(FajrAlarms.nextFireTime(emptyList(), 0))
    }
}
