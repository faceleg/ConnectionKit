// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"

#import "SVHTMLContext.h"
#import "SVHTMLValidator.h"
#import "SVTemplate.h"

#import "Registration.h"


@implementation SVRawHTMLGraphic 

@dynamic docType;
@dynamic HTMLString;
@dynamic lastValidMarkupDigest;
@dynamic shouldPreviewWhenEditing;

#pragma mark Metrics

- (void)makeOriginalSize;
{
    // Aim at auto-size
    [self setWidth:nil];
    [self setHeight:nil];
}

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
	// Show the real HTML if it's the pro-licensed edition publishing
	// OR we are previewing and the SVRawHTMLGraphic is marked as being OK for preview
	
    NSString *html = [self HTMLString];
    
    if (([context shouldWriteServerSideScripts] &&
         [context isForPublishingProOnly]) ||
        ([context isForEditing] &&
         [[self shouldPreviewWhenEditing] boolValue] &&
         [SVHTMLValidator validateFragment:html docType:[[self docType] intValue] error:NULL] >= kValidationStateLocallyValid))
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
