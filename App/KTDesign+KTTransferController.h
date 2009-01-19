//
//  KTDesign+KTTransferController.h
//  Marvel
//
//  Created by Mike on 07/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTDesign.h"

@class KTDocument;
@interface KTDesign (KTTransferController)

- (void)didPublishInDocument:(KTDocument *)document;

@end
