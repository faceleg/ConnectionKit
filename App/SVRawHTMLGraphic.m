// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"

#import "SVHTMLContext.h"
#import "SVHTMLValidator.h"
#import "SVInspectorViewController.h"
#import "SVTemplate.h"

#import "Registration.h"


@implementation SVRawHTMLGraphic 

@dynamic HTMLString;
@dynamic lastValidMarkupDigest;
@dynamic shouldPreviewWhenEditing;

- (BOOL)shouldValidateAsFragment; { return YES; }

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
    if ([self shouldWriteHTMLInline])
    {
        [context startElement:@"span"];
    }
    else
    {
        [context startElement:@"div" bindSizeToObject:self];
    }
    
    
	// Show the real HTML if it's the pro-licensed edition publishing
	// OR we are previewing and the SVRawHTMLGraphic is marked as being OK for preview
	
    NSString *fragment = [self HTMLString];
    
    if (([context shouldWriteServerSideScripts] && [context isForPublishing]) ||
        ([context isForEditing] && [[self shouldPreviewWhenEditing] boolValue]))
    {
        // Is the preview going to be understandable by WebKit? Judge this by making sure there's no problem with close tags
        NSString *html = [SVHTMLValidator HTMLStringWithFragment:(fragment ? fragment : @"")
                                               docType:KSHTMLWriterDocTypeHTML_4_01_Transitional];
        
        NSError *error = nil;
        ValidationState validation = [SVHTMLValidator validateHTMLString:html docType:KSHTMLWriterDocTypeHTML_4_01_Strict error:&error];
        if (validation >= kValidationStateLocallyValid)
        {
            NSString *description = [error localizedDescription];
            if (description)
            {
                if ([description rangeOfString:@" </"].location != NSNotFound) validation = kValidationStateUnparseable;
            }
        }
        
        if (validation >= kValidationStateLocallyValid)
        {
            if (fragment) [context writeHTMLString:fragment];
            [context addDependencyOnObject:self keyPath:@"HTMLString"];
        }
        else
        {
            [context writeHTMLString:[[[self class] invalidHTMLPlaceholderTemplate] templateString]];
        }
    }
    else
    {
        [context writeHTMLString:[[[self class] placeholderTemplate] templateString]];
    }
	
	[context addDependencyOnObject:self keyPath:@"contentType"];
    
    // Changes to any of these properties will be a visible change
    [context addDependencyOnObject:self keyPath:@"shouldPreviewWhenEditing"];
    
    
    
    [context endElement];
}

- (BOOL)canWriteHTMLInline { return YES; }

+ (SVTemplate *)placeholderTemplate;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"RawHTMLPlaceholder.html"] retain];
    }
    
    return result;
}

+ (SVTemplate *)invalidHTMLPlaceholderTemplate;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"InvalidHTMLPlaceholder.html"] retain];
    }
    
    return result;
}

- (NSString *)typeOfFile
{
	return (NSString *)kUTTypeHTML;
}

#pragma mark Inspector

- (NSString *)plugInIdentifier; { return @"sandvox.RawHTML"; }

+ (SVInspectorViewController *)makeInspectorViewController;
{
    return [[[SVInspectorViewController alloc]
             initWithNibName:@"RawHTMLInspector" bundle:nil]
            autorelease];
}

#pragma mark -
#pragma mark Properties

- (NSNumber *)contentType; { return [self valueForUndefinedKey:@"contentType"]; }
- (void)setContentType:(NSNumber *)contentType;
{
    [self setValue:contentType forUndefinedKey:@"contentType"]; 
}

- (BOOL) usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    if ([key isEqualToString:@"contentType"])
    {
        return YES;
    }
    else
    {
        return [super usesExtensiblePropertiesForUndefinedKey:key];
    }
}


@end
