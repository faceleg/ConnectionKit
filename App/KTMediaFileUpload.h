//
//  KTMediaFileUpload.h
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTPage;

@interface KTMediaFileUpload : NSManagedObject
{
}

- (NSString *)publishedPathRelativeToPage:(KTPage *)page;
@end
