//
//  SVRawHTMLGraphic.h
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@interface SVRawHTMLGraphic : SVGraphic  

@property(nonatomic, copy) NSNumber *docType;
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSData *lastValidMarkupDigest;
@property(nonatomic, copy) NSNumber *shouldPreviewWhenEditing;    // BOOL, madatory

@end



