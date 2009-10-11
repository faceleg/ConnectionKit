// 
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "SVPageletContent.h"
#import "SVSidebar.h"


@interface SVPagelet ()
@property(nonatomic, retain, readwrite) SVPageletContent *content;
@end


#pragma mark -


@implementation SVPagelet 

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Create a corresponding content object
    SVPageletContent *content = [NSEntityDescription
                                 insertNewObjectForEntityForName:@"PageletContent"
                                 inManagedObjectContext:[self managedObjectContext]];
    
    [self setContent:content];
}

@dynamic titleHTMLString;
@dynamic sidebar;
@dynamic content;

@end
