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

- (NSTextAlignment)alignment; { return NSNaturalTextAlignment; }

#pragma mark Graphical Text

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;
{
    return nil;
}

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
