// 
//  SVTextBox.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVTextBox.h"

#import "SVGraphicFactory.h"
#import "SVRichText.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "SVInspectorViewController.h"
#import "SVTemplate.h"


@interface SVTextBox ()
@property(nonatomic, retain, readwrite) SVRichText *body;
@end


#pragma mark -


@implementation SVTextBox 

- (NSString *)plugInIdentifier; { return [[SVGraphicFactory textBoxFactory] identifier]; }

#pragma mark Body Text

@dynamic body;

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // Create corresponding body text
    [self setBody:[SVRichText insertPageletBodyIntoManagedObjectContext:[self managedObjectContext]]];
}

- (void)pageDidChange:(id <SVPage>)page;
{
    [super pageDidChange:page];
    
    // Size any embedded images to fit. #105069
    NSSet *graphics = [[[self body] attachments] valueForKey:@"graphic"];
    [graphics makeObjectsPerformSelector:_cmd withObject:page];
}

#pragma mark Options

- (NSNumber *)isBlockQuote; { return [self valueForUndefinedKey:@"isBlockQuote"]; }
- (void)setIsBlockQuote:(NSNumber *)isQuote; { [self setValue:isQuote forUndefinedKey:@"isBlockQuote"]; }

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    return ([key isEqualToString:@"isBlockQuote"] ?
            YES :
            [super usesExtensiblePropertiesForUndefinedKey:key]);
}

#pragma mark Intro & Caption

- (BOOL)canHaveCaption; { return NO; }

- (BOOL)canHaveIntroduction { return NO; }

#pragma mark Metrics

- (void)makeOriginalSize;
{
    [super makeOriginalSize];
    
    if ([[self isBlockQuote] boolValue])
    {
        [self setWidth:nil];
    }
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    // Make sure we have a body! #124620
    if (![self body])
    {
        SVRichText *body = [SVRichText insertPageletBodyIntoManagedObjectContext:[self managedObjectContext]];
        [body setString:@"<p><br /></p>"];
        [self setBody:body];
    }
    
    
    static SVTemplate *sBodyTemplate;
    if (!sBodyTemplate)
    {
        sBodyTemplate = [[SVTemplate templateNamed:@"TextBoxBodyTemplate.html"] retain];
    }
    
    SVHTMLTemplateParser *parser =
    [[SVHTMLTemplateParser alloc] initWithTemplate:[sBodyTemplate templateString]
                                         component:self];
    
    [parser parseIntoHTMLContext:context];
    [parser release];
}

- (NSString *)graphicClassName;
{
    return ([[self isBlockQuote] boolValue] ? @"blockquote-container" : [super graphicClassName]);
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Text
    [propertyList setObject:[[self body] serializedProperties] forKey:@"body"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    [[self body] awakeFromPropertyList:[propertyList objectForKey:@"body"]];
}

#pragma mark Inspector

+ (SVInspectorViewController *)makeInspectorViewController;
{
    return [[[SVInspectorViewController alloc]
             initWithNibName:@"TextBoxInspector" bundle:nil]
            autorelease];
}

@end


#pragma mark -


@implementation SVTextBoxBody

- (SVTextDOMController *)newTextDOMControllerWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node
{
    SVTextDOMController *result = [super newTextDOMControllerWithIdName:elementID ancestorNode:node];
    [result setRepresentedObject:[self valueForKey:@"pagelet"]];
    return result;
}

@end

