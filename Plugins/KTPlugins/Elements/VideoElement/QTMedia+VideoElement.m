//
//  QTMedia+VideoElement.m
//  KTPlugins
//
//  Created by Mike on 15/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "QTMedia+VideoElement.h"


@implementation QTMedia (VideoElement)

- (OSType)sampleDescriptionCodec
{
	OSType result = 0;
	if (GetMediaSampleDescriptionCount([self quickTimeMedia]) != 0)
	{
		SampleDescriptionHandle sd = (SampleDescriptionHandle)NewHandle(0);
		GetMediaSampleDescription([self quickTimeMedia], 1, (SampleDescriptionHandle)sd);
		result = (**sd).dataFormat;
		DisposeHandle((Handle)sd);		// gnrc
	}
	return result;
}

- (NSString *)sampleDescriptionCodecName
{
	CodecInfo ci;
	OSType sampleDescriptionCodec = [self sampleDescriptionCodec];
	if (!sampleDescriptionCodec) return nil;
	
	GetCodecInfo(&ci, sampleDescriptionCodec, 0);
	CFStringRef result = CFStringCreateWithPascalString (kCFAllocatorDefault, ci.typeName, kCFStringEncodingMacRoman);
	return [(NSString *)result autorelease];
}

@end
