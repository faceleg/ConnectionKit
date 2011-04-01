//
//  SVFlash.h
//  Sandvox
//
//  Created by Dan Wood on 9/9/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVAudioVisualPlugIn.h"
#import "KSSimpleURLConnection.h"
#import <QTKit/QTKit.h>

@class SVMediaRecord;



@interface SVFlash : SVAudioVisualPlugIn
{
	BOOL _showMenu;
	NSString *_flashvars;
	
	// flash parsing support ... ivars mean that this object can't be parsing more than one flash file at a time, but this shouldn't happen.
	int myBitOffset;
	char myCurrentByte;
	char *myBytePointer;		// an unretained pointer, just stored here so it's not global.
	
	KSSimpleURLConnection *_dimensionCalculationConnection;

}

@property (retain) KSSimpleURLConnection *dimensionCalculationConnection;


@property(nonatomic, copy) NSString *flashvars;	// http://kb2.adobe.com/cps/164/tn_16417.html
@property (nonatomic) BOOL showMenu;

@end



