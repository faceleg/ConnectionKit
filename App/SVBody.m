// 
//  SVPageletBody.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBody.h"

#import "SVPagelet.h"
#import "SVBodyElement.h"
#import "SVBodyTextDOMController.h"
#import "SVHTMLContext.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSortDescriptor+Karelia.h"


@interface SVBody ()
@end

@interface SVBody (CoreDataGeneratedAccessors)
- (void)addElementsObject:(SVBodyElement *)value;
- (void)removeElementsObject:(SVBodyElement *)value;
- (void)addElements:(NSSet *)value;
- (void)removeElements:(NSSet *)value;
@end


#pragma mark -


@implementation SVBody 

#pragma mark Init

+ (SVBody *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"PageBody"
                                         inManagedObjectContext:context];
}

+ (SVBody *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"TextBoxBody"
                                         inManagedObjectContext:context];
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Should we take the opportinity to create a starter paragraph?
}

@dynamic string;
@dynamic attachments;

#pragma mark HTML

- (void)writeHTML
{
    //  Piece together each of our elements to generate the HTML
    SVHTMLContext *context = [SVHTMLContext currentContext];
    [context writeString:[self string]];
    
    return;
    
    
    
    [[self class] writeContentObjects:[self orderedElements]];
}

#pragma mark Editing

- (Class)DOMControllerClass; { return [SVBodyTextDOMController class]; }

@end
