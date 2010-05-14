//
//  SVTextBox.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVGraphic.h"

@class SVRichText;

@interface SVTextBox :  SVGraphic  

#pragma mark Body Text
@property(nonatomic, retain, readonly) SVRichText *body;


@end



