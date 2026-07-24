/**
 * Central trigger recursion/bypass control. Every trigger handler consults this before
 * re-entering logic that itself performs DML on the same object.
 */
public without sharing class TriggerControl {
    private static final Set<String> bypassed = new Set<String>();

    public static void bypass(String objectName) { bypassed.add(objectName); }
    public static void clearBypass(String objectName) { bypassed.remove(objectName); }
    public static Boolean isBypassed(String objectName) { return bypassed.contains(objectName); }
    public static void clearAll() { bypassed.clear(); }
}
