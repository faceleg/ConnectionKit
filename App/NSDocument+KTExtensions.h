//
//  NSDocument+KTExtensions.h
//  Marvel
//
//  Created by Mike on 21/10/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSDocument (KTExtensions)

- (BOOL)copyDocumentToURL:(NSURL *)URL recycleExistingFiles:(BOOL)replaceExisting error:(NSError **)error;

@end
