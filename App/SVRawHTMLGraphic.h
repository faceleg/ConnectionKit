//
//  SVRawHTMLGraphic.h
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"
#import "KTHTMLEditorController.h"


@class SVTemplate;


@interface SVRawHTMLGraphic : SVGraphic <KTHTMLSourceObject> 

@property(nonatomic, copy) NSNumber *contentType;
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSData *lastValidMarkupDigest;
@property(nonatomic, copy) NSNumber *shouldPreviewWhenEditing;    // BOOL, mandatory

+ (SVTemplate *)placeholderTemplate;
+ (SVTemplate *)invalidHTMLPlaceholderTemplate;

@end



