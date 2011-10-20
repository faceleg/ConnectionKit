// 
//  SVAuxiliaryPageletText.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAuxiliaryPageletText.h"

#import "SVGraphic.h"
#import "SVHTMLTextBlock.h"


@implementation SVAuxiliaryPageletText 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"<p><br /></p>" forKey:@"string"];
}

@dynamic pagelet;
@dynamic hidden;

- (id <SVGraphic>)captionGraphic; { return nil; }

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setHTMLSourceObject:[self pagelet]];
    [textBlock setHTMLSourceKeyPath:@"caption"];
    [textBlock setEditable:YES];
    [textBlock setImportsGraphics:YES];
    [textBlock setCustomCSSClassName:@"caption"];
    
    [textBlock writeHTML:context];
    [textBlock release];
}

- (BOOL)isPagelet; { return NO; }
- (BOOL)isCallout; { return NO; }
- (BOOL)shouldWriteHTMLInline; { return YES; }
- (BOOL)displayInline; { return NO; }

#pragma mark Metrics

@dynamic width;
- (NSNumber *)contentWidth; { return [self width]; }
- (void)setContentWidth:(NSNumber *)width; { [self setWidth:width]; }
+ (NSSet *)keyPathsForValuesAffectingContentWidth; { return [NSSet setWithObject:@"width"]; }

- (NSNumber *)height; { return nil; }
- (NSNumber *)contentHeight; { return NSNotApplicableMarker; }
- (void)setContentHeight:(NSNumber *)height; { }

- (NSNumber *)containerWidth; { return [self width]; }

- (BOOL)isExplicitlySized; { return NO; }
- (BOOL)isExplicitlySized:(SVHTMLContext *)context; { return NO; }

@end
