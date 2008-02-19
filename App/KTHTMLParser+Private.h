//
//  KTHTMLParser+Private.h
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTHTMLParser (Private)

- (KTHTMLParserMasterCache *)cache;

- (NSString *)resourceFilePathRelativeToCurrentPage:(NSString *)resourceFile;
- (void)didEncounterResourceFile:(NSString *)resourcePath;

@end
