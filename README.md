# Hak5 Pineapple Pager 🍍📟

---

## About the WiFi Pineapple Pager

A WiFi Pineapple built for hackers who don’t stay put.

The **WiFi Pineapple Pager** combines Hak5’s PineAP engine with a fast, highly optimized embedded UI.  
Ringtones provide audible feedback for alerts, recon activity, payload events, and system notifications — even when the device isn’t being actively watched.

---

## About Pager Ringtones

Pager ringtones are **short audible sequences** used by the device to communicate state, alerts, and activity.

They are:

- Authored in **RTTTL**
- Parsed and played directly by the Pager
- Used for alerts, notifications, and event feedback
- Lightweight and efficient for embedded hardware

Ringtones in this repository are the **source definitions** used directly by the device — **no compilation required**.

---

## About RTTTL

RTTTL (Ring Tone Text Transfer Language) is a simple text-based format originally designed for early mobile phones.

A typical RTTTL ringtone looks like:

---

### File Format

- Ringtones must be written in **RTTTL**
- Files should contain **only** the RTTTL definition
- No binary or encoded audio formats are allowed

---

### Design Best Practices

- Keep ringtones short and distinct
- Avoid extremely high or low frequencies
- Ensure tones are clearly audible on the Pager speaker
- Avoid excessive repetition or long melodies
- Test at multiple volume levels

Ringtones that are excessively long, annoying, or disruptive may be rejected.

---
