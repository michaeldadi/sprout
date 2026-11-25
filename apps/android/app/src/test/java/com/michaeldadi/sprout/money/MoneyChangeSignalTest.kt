package com.michaeldadi.sprout.money

import org.junit.Assert.*
import org.junit.Test

class MoneyChangeSignalTest {
    @Test fun authRevocationAndMalformedFramesStopWithoutThrowing() {
        for (text in listOf("{\"type\":\"error\",\"data\":{\"code\":401}}","bad-json"," ".repeat(16385))) assertEquals(MoneyChangeSignal.Frame.STOP,MoneyChangeSignal.frame(text,"owner-channel","subscription"))
    }
    @Test fun onlyTheSubscribedPrivateRevisionCanSignalRefresh() {
        assertEquals(MoneyChangeSignal.Frame.CONNECTED,MoneyChangeSignal.frame("{\"type\":\"connected\"}","owner-channel","subscription"))
        assertEquals(MoneyChangeSignal.Frame.SIGNAL,MoneyChangeSignal.frame("{\"type\":\"event\",\"data\":{\"channels\":[\"owner-channel\"]}}","owner-channel","subscription"))
        assertEquals(MoneyChangeSignal.Frame.SIGNAL,MoneyChangeSignal.frame("{\"type\":\"event\",\"data\":{\"subscriptions\":[\"subscription\"]}}","owner-channel","subscription"))
        assertEquals(MoneyChangeSignal.Frame.IGNORE,MoneyChangeSignal.frame("{\"type\":\"event\",\"data\":{\"channels\":[\"peer-channel\"]}}","owner-channel","subscription"))
    }
}
