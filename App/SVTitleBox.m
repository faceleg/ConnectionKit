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
- (void)setTextHTMLString:(NSString *)string
{
    [self willChangeValueForKey:@"text"];
    [self willChangeValueForKey:@"textHTMLString"];
    
    [self setPrimitiveValue:nil forKey:@"text"];    // cause it be regenerated on demand
    [self setPrimitiveValue:string forKey:@"textHTMLString"];
    
    [self didSetText];
    
    [self didChangeValueForKey:@"text"];
    [self didChangeValueForKey:@"textHTMLString"];
}

- (NSString *)text	// get title, but without attributes
{
    [self willAccessValueForKey:@"text"];
    
    NSString *result = [self primitiveValueForKey:@"text"];
    if (!result)
    {
        NSString *html = [self textHTMLString];
        result = [html stringByConvertingHTMLToPlainText];
        [self setPrimitiveValue:result forKey:@"text"];
    }
    
    [self didAccessValueForKey:@"text"];
    return result;
}

- (void)setText:(NSString *)value
{
    [self willChangeValueForKey:@"text"];
    [self willChangeValueForKey:@"textHTMLString"];
    
    [self setPrimitiveValue:value forKey:@"text"];
    [self setPrimitiveValue:[KSXMLWriter stringFromCharacters:value] forKey:@"textHTMLString"];
    
    [self didSetText];
    
    [self didChangeValueForKey:@"text"];
    [self didChangeValueForKey:@"textHTMLString"];
}

- (void)didSetText; { }

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
    return (keyPath ? [NSSet setWithObject:keyPath] : nil);
}

+ (NSString *)alignmentKeyPath; { return nil; }

- (NSWritingDirection)textBaseWritingDirection;
{
    NSString *keyPath = [[self class] textBaseWritingDirectionKeyPath];
    NSNumber *result = (keyPath ? [self valueForKeyPath:keyPath] : nil);
    return (result ? [result intValue] : NSWritingDirectionNatural);
}
- (void)setTextBaseWritingDirection:(NSWritingDirection)writingDirection;
{
    [self setValue:[NSNumber numberWithInt:writingDirection]
        forKeyPath:[[self class] textBaseWritingDirectionKeyPath]];
}
+ (NSSet *)keyPathsForValuesAffectingTextBaseWritingDirection;
{
    NSString *keyPath = [self textBaseWritingDirectionKeyPath];
    return (keyPath ? [NSSet setWithObject:keyPath] : nil);
}

+ (NSString *)textBaseWritingDirectionKeyPath { return nil; }

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

+ (NSString *)alignmentKeyPath; { return @"master.siteTitleAlignment"; }
+ (NSString *)textBaseWritingDirectionKeyPath; { return @"master.siteTitleWritingDirection"; }

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;
{
    return ([[context page] isRootPage] ? @"h1h" : @"h1");
}

@end


#pragma mark -


@implementation SVSiteSubtitle 

+ (NSString *)alignmentKeyPath; { return @"master.taglineAlignment"; }
+ (NSString *)textBaseWritingDirectionKeyPath; { return @"master.taglineWritingDirection"; }

@end
