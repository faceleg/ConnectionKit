//
//  KTExternalMediaFile.h
//  Marvel
//
//  Created by Mike on 11/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTMediaFile.h"

@class BDAlias;
@interface KTExternalMediaFile : KTMediaFile
{
}

- (BDAlias *)alias;
- (void)setAlias:(BDAlias *)alias;

@end


@interface KTExternalMediaFile (Internal) <KTPasteboardArchiving>
+ (id)insertNewMediaFileWithAlias:(BDAlias *)alias inManagedObjectContext:(NSManagedObjectContext *)moc;
@end
