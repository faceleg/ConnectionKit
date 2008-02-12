//
//  KTTransferController+Internal.h
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTTransferController.h"


@interface KTTransferController (Internal)
- (void)uploadFile:(NSString *)localPath toFile:(NSString *)remotePath;
- (void)recursivelyCreateDirectoriesFromPath:(NSString *)path setPermissionsOnAllFolders:(BOOL)flag;
@end


@interface KTTransferController (Media)
- (void)threadedUploadMediaFiles:(NSSet *)mediaFileUploads;
- (NSSet *)mediaFileUploads;
- (void)removeAllMediaFileUploads;

- (NSSet *)parsedMediaFileUploads;
- (NSSet *)staleParsedMediaFileUploads;
- (void)addParsedMediaFileUpload:(KTMediaFileUpload *)mediaFileUpload;
- (void)removeAllParsedMediaFileUploads;
@end
