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
#import "NSString+Karelia.h"
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

- (NSUInteger)minWidth; { return 16; }

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
    [context pushClassName:@"HTMLElement"];
    [context addCSSString:@".HTMLElement { overflow:hidden; }"];
    
    if ([self shouldWriteHTMLInline])
    {
        [context pushClassName:@"graphic-container"];
        [context startElement:@"span"];
    }
    else
    {
        if ([self isPagelet])   // use standard resize behaviour when inline. #116251
        {
            [context buildAttributesForResizableElement:@"div"
                                                 object:self
                                     DOMControllerClass:nil
                                              sizeDelta:NSZeroSize
                                                options:SVResizingDisableVertically];
        }
        [context startElement:@"div"];
        [context startNewline];
    }
    
    
    {
        // Show the real HTML if it's the pro-licensed edition publishing
        // OR we are previewing and the SVRawHTMLGraphic is marked as being OK for preview
        
        NSString *fragment = [self HTMLString];
        [context addDependencyOnObject:self keyPath:@"HTMLString"];
        
        
        [context addDependencyOnObject:self keyPath:@"contentType"];
        NSString *contentType = [self contentType];
        
        
        BOOL write = YES;
        if (!contentType ||     // treat like HTML
            [contentType isEqualToString:(NSString *)kUTTypeHTML])
        {
            if ([context isForEditing])
            {
                if ([[self shouldPreviewWhenEditing] boolValue])
                {
                    // Is the preview going to be understandable by WebKit? Judge this by making sure there's no problem with close tags
                    NSString *html = [SVHTMLValidator HTMLStringWithFragment:(fragment ? fragment : @"")
                                                                     docType:KSHTMLWriterDocTypeHTML_5];
                    
                    NSError *error = nil;
                    ValidationState validation = [SVHTMLValidator validateHTMLString:html docType:KSHTMLWriterDocTypeHTML_5 error:&error];
                    if (validation == kValidationStateValidationError)
                    {
                        NSString *description = [error localizedDescription];
                        if (description)
                        {
                            if ([description rangeOfString:@" </"].location != NSNotFound) validation = kValidationStateUnparseable;
                        }
                    }
                    
                    if (validation < kValidationStateValidationError)
                    {
                        // Invalid HTML should use placeholder instead
                        SVTemplate *template = [[self class] invalidHTMLPlaceholderTemplate];
                        NSString *parsed = [context parseTemplate:template object:self];
                        [context writeHTMLString:parsed];
                        write = NO;
                    }
                }
                else
                {
                    write = NO;
                }
            }
        }
        else
        {
            // don't show while editing
            write = ![context isForEditing];
        }
        
        if (write && fragment)
        {
            [context writeHTMLString:fragment];
        }
        
        // Changes to any of these properties will be a visible change
        [context addDependencyOnObject:self keyPath:@"shouldPreviewWhenEditing"];
    }
    [context endElement];
}

- (BOOL)canWriteHTMLInline { return YES; }

+ (SVTemplate *)placeholderTemplate;
{
	// gets "placeholderString" from properties
    static SVTemplate *sRawHTMLPlaceholderTemplate = nil;
    if (!sRawHTMLPlaceholderTemplate)
    {
		SVTemplate *template = [SVTemplate templateNamed:@"RawHTMLPlaceholder.html"];
        sRawHTMLPlaceholderTemplate = [template retain];
    }   
    return sRawHTMLPlaceholderTemplate;
}

+ (SVTemplate *)invalidHTMLPlaceholderTemplate;
{
	// String:  NSLocalizedString(@"Invalid HTML", "shown in raw HTML object");
    static SVTemplate *sInvalidHTMLPlaceholderTemplate = nil;
    if (!sInvalidHTMLPlaceholderTemplate)
    {
        sInvalidHTMLPlaceholderTemplate = [[SVTemplate templateNamed:@"InvalidHTMLPlaceholder.html"] retain];
    }
    
    return sInvalidHTMLPlaceholderTemplate;
}

// You never know if user has entered something bizarre that only displays right during a full load
- (BOOL)requiresPageLoad; { return YES; }

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

- (NSString *)contentType; { return [self valueForUndefinedKey:@"contentType"]; }
- (void)setContentType:(NSString *)contentType;
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

- (NSString *)contentTypeDescription
{
	NSString *contentType = self.contentType;
	if (!contentType
	 || [contentType conformsToUTI:(NSString *)kUTTypeHTML])	return @"HTML";
	if ([contentType conformsToUTI:@"public.php-script"])		return @"PHP";
	if ([contentType conformsToUTI:@"com.netscape.javascript-source"])	return @"JavaScript";
	if ([contentType conformsToUTI:(NSString *)kUTTypeText])	return NSLocalizedString(@"Other Markup", @"description of other kind of HTML/scripting code");
	
	// Fallback
	NSString *result = NSMakeCollectable(UTTypeCopyDescription((CFStringRef)self.contentType));
	[NSMakeCollectable(result) autorelease];
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingContentTypeDescription
{
    return [NSSet setWithObject:@"contentType"];
}




@end
