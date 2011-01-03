//
//  KTImageTextCell.h
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

// from Apple's ImageAndTextCell class

#import <AppKit/AppKit.h>


@interface SVShadowingImageCell : NSImageCell
{
@private
    BOOL    _shadow;
}
@property(nonatomic) BOOL hasShadow;
@end


@interface KTImageTextCell : NSTextFieldCell
{
  @private
    NSImage                 *myImage;
    BOOL                    _thumbnail;
    SVShadowingImageCell	*myImageCell;
	float                   myMaxImageSize;
    int                     myPadding;
	int                     myStaleness;
	BOOL                    myIsDraft;
	BOOL                    myIsPublishable;
	BOOL                    myIsRoot;
	BOOL                    myHasCodeInjection;
}

@property(nonatomic, retain) NSImage *image;
@property(nonatomic) BOOL isImageThumbnail;

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
