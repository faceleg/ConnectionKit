//
//  KTImageTextCell.h
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

// from Apple's ImageAndTextCell class

#import <AppKit/AppKit.h>

@interface KTImageTextCell : NSTextFieldCell
{
  @private
    NSImage		*myImage;
    NSImageCell	*myImageCell;
	float		myMaxImageSize;
    int			myPadding;
	int			myStaleness;
	BOOL		myIsDraft;
	BOOL		myIsPublishable;
	BOOL		myIsRoot;
	BOOL		myHasCodeInjection;
}

- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (float)maxImageSize;
- (void)setMaxImageSize:(float)width;

- (int)staleness;
- (void)setStaleness:(int)aStaleness;

- (BOOL)isDraft;
- (void)setDraft:(BOOL)flag;

- (BOOL)isPublishable;
- (void)setPublishable:(BOOL)flag;

- (void)setPadding:(int)anInt;
- (int)padding;

- (BOOL)isRoot;	// The root page has extra padding at the top
- (void)setRoot:(BOOL)isRoot;

- (BOOL)hasCodeInjection;
- (void)setHasCodeInjection:(BOOL)flag;
- (NSRect)codeInjectionIconRectForBounds:(NSRect)cellFrame;


#pragma mark Drawing
- (void)drawTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;


@end
