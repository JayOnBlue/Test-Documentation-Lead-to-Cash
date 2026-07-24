/**
 * Field-level validation helpers shared by the REST intake surfaces and the trigger
 * handlers. Each check is deliberately tiny; the value is one shared vocabulary of rules.
 */
public inherited sharing class ValidationUtils {
    public static Boolean isValidEmail(String email) {
        return String.isNotBlank(email) && Pattern.matches('^[\\w.+-]+@[\\w-]+\\.[\\w.-]+$', email);
    }
    public static Boolean isBusinessEmail(String email) {
        if (!isValidEmail(email)) return false;
        String domain = email.substringAfter('@').toLowerCase();
        return domain != 'gmail.com' && domain != 'yahoo.com' && domain != 'hotmail.com' && domain != 'outlook.com';
    }
    public static Boolean isValidPhone(String phone) {
        return String.isNotBlank(phone) && phone.replaceAll('[^0-9]', '').length() >= 7;
    }
    public static Boolean isPositive(Decimal value) { return value != null && value > 0; }
    public static Boolean isNonNegative(Decimal value) { return value != null && value >= 0; }
    public static Boolean isPercent(Decimal value) { return value != null && value >= 0 && value <= 100; }
    public static Boolean isFutureDate(Date d) { return d != null && d > Date.today(); }
    public static Boolean isPastDate(Date d) { return d != null && d < Date.today(); }
    public static Boolean isWithinDays(Date d, Integer days) {
        return d != null && d >= Date.today() && d <= Date.today().addDays(days);
    }
    public static Boolean hasText(String value, Integer minLength) {
        return String.isNotBlank(value) && value.trim().length() >= minLength;
    }
    public static Boolean inSet(String value, Set<String> allowed) {
        return value != null && allowed.contains(value);
    }
    public static String normalizeCountry(String country) {
        if (String.isBlank(country)) return country;
        String c = country.trim().toUpperCase();
        if (c == 'USA' || c == 'US' || c == 'UNITED STATES OF AMERICA') return 'United States';
        if (c == 'UK' || c == 'GREAT BRITAIN') return 'United Kingdom';
        return country.trim();
    }
    public static String truncate(String value, Integer maxLength) {
        if (value == null) return null;
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }
}
