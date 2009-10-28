// 
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "SVPageletBody.h"
#import "SVSidebar.h"
#import "SVSidebarEntry.h"

#import "NSString+Karelia.h"


@interface SVPagelet ()
@property(nonatomic, retain, readwrite) SVPageletBody *body;
@end


#pragma mark -


@implementation SVPagelet 

+ (SVPagelet *)pageletWithPage:(KTPage *)page;
{
	OBPRECONDITION([page managedObjectContext]);
	
	
    // Create sidebar entry
    SVSidebarEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"PageletSidebarEntry" inManagedObjectContext:[page managedObjectContext]];
    [entry setSidebar:[page sidebar]];
    
    
	// Create the pagelet
	SVPagelet *result = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
													  inManagedObjectContext:[page managedObjectContext]];
	OBASSERT(result);
	[entry setPagelet:result];
	
    
	return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // UID
    [self setPrimitiveValue:[NSString shortUUIDString] forKey:@"elementID"];
    
    
    // Create a corresponding content object
    SVPageletBody *content = [NSEntityDescription
                                 insertNewObjectForEntityForName:@"PageletBody"
                                 inManagedObjectContext:[self managedObjectContext]];
    
    [self setBody:content];
}

@dynamic elementID;
@dynamic titleHTMLString;
@dynamic body;

#pragma mark Sidebar

@dynamic sidebars;
@dynamic sidebarSortKey;

@end
