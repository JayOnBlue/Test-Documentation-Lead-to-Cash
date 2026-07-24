/**
 * Trigger handler for Contact: a new contact on an account may be the missing primary
 * role for that account's open opportunities.
 */
public with sharing class ContactTriggerHandler {
    public static void afterInsert(List<Contact> contacts) {
        Set<Id> accountIds = CollectionUtils.extractIds(contacts, 'AccountId');
        if (!accountIds.isEmpty()) ContactRoleSyncService.ensurePrimaryRoles(accountIds);
    }
}
