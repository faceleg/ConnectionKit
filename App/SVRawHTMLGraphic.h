//
//  SVRawHTMLGraphic.h
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@interface SVRawHTMLGraphic : SVGraphic  

@property(nonatomic, retain) NSNumber *docType;
@property(nonatomic, retain) NSString *HTMLString;
@property(nonatomic, retain) NSNumber *shouldPreviewWhenEditing;    // BOOL, madatory

@end



