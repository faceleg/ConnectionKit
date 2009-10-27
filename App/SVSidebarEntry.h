//
//  SVSidebarEntry.h
//  Sandvox
//
//  Created by Mike on 27/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVInheritedSidebarEntry;
@class SVSidebar;

@interface SVSidebarEntry :  NSManagedObject  
{
}

@property (nonatomic, retain) SVSidebarEntry * previousEntry;
@property (nonatomic, retain) SVSidebar * sidebar;
@property (nonatomic, retain) NSSet* inheritedEntries;
@property (nonatomic, retain) SVSidebarEntry * nextEntry;

@end


@interface SVSidebarEntry (CoreDataGeneratedAccessors)
- (void)addInheritedEntriesObject:(SVInheritedSidebarEntry *)value;
- (void)removeInheritedEntriesObject:(SVInheritedSidebarEntry *)value;
- (void)addInheritedEntries:(NSSet *)value;
- (void)removeInheritedEntries:(NSSet *)value;

@end

