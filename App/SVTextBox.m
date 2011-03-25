// 
//  SVTextBox.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVTextBox.h"

#import "SVRichText.h"
#import "SVHTMLTemplateParser.h"
#import "SVTemplate.h"


@interface SVTextBox ()
@property(nonatomic, retain, readwrite) SVRichText *body;
@end


#pragma mark -


@implementation SVTextBox 

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

#pragma mark Intro & Caption

- (BOOL)canHaveCaption; { return NO; }

- (BOOL)canHaveIntroduction { return NO; }

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
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

@end
