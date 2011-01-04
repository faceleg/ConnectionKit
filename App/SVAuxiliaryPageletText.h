//
//  SVAuxiliaryPageletText.h
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//


#import "SVRichText.h"
#import "SVGraphic.h"


@interface SVAuxiliaryPageletText : SVRichText <SVGraphic> 

@property(nonatomic, retain, readonly) SVGraphic *pagelet;
@property(nonatomic, retain) NSNumber *hidden; // BOOL, mandatory

@end



