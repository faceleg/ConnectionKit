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


@interface SVPagelet ()
@property(nonatomic, retain, readwrite) SVPageletBody *body;
@end


#pragma mark -


@implementation SVPagelet 

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Create a corresponding content object
    SVPageletBody *content = [NSEntityDescription
                                 insertNewObjectForEntityForName:@"PageletBody"
                                 inManagedObjectContext:[self managedObjectContext]];
    
    [self setBody:content];
}

@dynamic titleHTMLString;
@dynamic sidebar;
@dynamic body;

@end
