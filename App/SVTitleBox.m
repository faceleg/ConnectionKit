// 
//  SVTitleBox.m
//  Sandvox
//
//  Created by Mike on 07/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVTitleBox.h"

#import "SVHTMLContext.h"
#import "KTPage.h"

#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"

#import "KSStringXMLEntityEscaping.h"
#import "KSStringHTMLEntityUnescaping.h"


@implementation SVTitleBox 

#pragma mark Content

@dynamic textHTMLString;

- (NSString *)text	// get title, but without attributes
{
	NSString *html = [self textHTMLString];
	NSString *result = [html stringByConvertingHTMLToPlainText];
	return result;
}

- (void)setText:(NSString *)value
{
	[self setTextHTMLString:[KSXMLWriter stringFromCharacters:value]];
}

+ (NSSet *)keyPathsForValuesAffectingText
{
    return [NSSet setWithObject:@"textHTMLString"];
}

@dynamic hidden;

#pragma mark Alignment

- (NSTextAlignment)alignment;
{
    NSString *keyPath = [[self class] alignmentKeyPath];
    NSNumber *result = (keyPath ? [self valueForKeyPath:keyPath] : nil);
    return (result ? [result intValue] : NSNaturalTextAlignment);
}
- (void)setAlignment:(NSTextAlignment)alignment;
{
    [self setValue:[NSNumber numberWithInt:alignment]
        forKeyPath:[[self class] alignmentKeyPath]];
}
+ (NSSet *)keyPathsForValuesAffectingAlignment;
{
    NSString *keyPath = [self alignmentKeyPath];
    return (keyPath ? [NSSet setWithObject:[self alignmentKeyPath]] : nil);
}

+ (NSString *)alignmentKeyPath; { return nil; }

#pragma mark Graphical Text

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;
{
    return nil;
}

#pragma mark Graphic

- (BOOL)shouldWriteHTMLInline; { return NO; }
- (BOOL)displayInline; { return NO; }

@end


#pragma mark -


@implementation SVSiteTitle 

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;
{
    return ([[context page] isRootPage] ? @"h1h" : @"h1");
}

@end


#pragma mark -


@implementation SVSiteSubtitle 

@end
