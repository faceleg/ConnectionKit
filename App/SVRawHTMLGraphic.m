// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"

#import "SVHTMLContext.h"
#import "SVTemplate.h"
#import "Registration.h"


@implementation SVRawHTMLGraphic 

@dynamic docType;
@dynamic HTMLString;
@dynamic lastValidMarkupDigest;
@dynamic shouldPreviewWhenEditing;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
	// Show the real HTML if it's the pro-licensed edition publishing
	// OR we are previewing and the SVRawHTMLGraphic is marked as being OK for preview
	
    if ( [context shouldWriteServerSideScripts]
			|| ([context isForEditing] && [[self shouldPreviewWhenEditing] boolValue])
		)
    {
        [context writeHTMLString:[self HTMLString]];
        [context addDependencyOnObject:self keyPath:@"HTMLString"];
    }
    else
    {
        [context writeHTMLString:[[[self class] placeholderTemplate] templateString]];
    }
	
    [context limitToMaxDocType:[[self docType] intValue]];
	[context addDependencyOnObject:self keyPath:@"docType"];
    
    // Changes to any of these properties will be a visible change
    [context addDependencyOnObject:self keyPath:@"shouldPreviewWhenEditing"];
}

+ (SVTemplate *)placeholderTemplate;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"RawHTMLPlaceholder.html"] retain];
    }
    
    return result;
}

@end
