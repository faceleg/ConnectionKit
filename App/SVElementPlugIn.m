//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVElementPlugIn.h"

#import "KTAbstractHTMLPlugin.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"


@interface SVAbstractElementPlugIn ()
@property(nonatomic, retain) id delegateOwner;
@end


@implementation SVAbstractElementPlugIn

#pragma mark Init

+ (id <SVElementPlugIn>)elementPlugInWithPropertiesStorage:(NSMutableDictionary *)propertyStorage;
{
    return [[[self alloc] initWithPropertiesStorage:propertyStorage] autorelease];
}

- (id)initWithPropertiesStorage:(NSMutableDictionary *)storage;
{
    self = [self init];
    _propertiesStorage = [storage retain];
    return self;
}

#pragma mark Content

- (NSString *)HTMLString;
{
    NSString *result = [NSString stringWithFormat:
                        @"<div id=\"%@\">%@</div>",
                        [self elementID],
                        [self innerHTMLString]];
    return result;
}

- (NSString *)elementID
{
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

- (NSString *)innerHTMLString;
{
    // Parse our built-in template
    NSString *template = [[[self delegateOwner] plugin] templateHTMLAsString];
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template
                                                                        component:self];
    
    NSString *result = [parser parseTemplate];
    [parser release];
    
    return result;
}

@synthesize propertiesStorage = _propertiesStorage;

- (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }

#pragma mark Legacy

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject { }

@synthesize delegateOwner = _delegateOwner;

- (KTMediaManager *)mediaManager { return [[self delegateOwner] mediaManager]; }

- (KTPage *)page
{
    return [[[[[[self delegateOwner] body] pagelet] sidebars] anyObject] page];
}

@end
