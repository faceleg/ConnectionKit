//
//  KTAbstractDataSource.h
//  KTComponents
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "KTAbstractElement.h"

// Priority
typedef enum { 
	KTSourcePriorityNone = 0,				// Can't handle drag clipboard
	KTSourcePriorityMinimum = 1,			// Bare minimum, for a generic file handler
	KTSourcePriorityFallback = 10,			// Could handle it, but there are probably better handlers
	KTSourcePriorityReasonable = 20,		// Reasonable handler, unless there's a better one
	KTSourcePriorityTypical = 30,			// Relatively specialized handler
	KTSourcePriorityIdeal = 40,				// More specialized, better equipped than lessers.
	KTSourcePrioritySpecialized = 50		// Specialized for these data, e.g. Amazon Books URL
} KTSourcePriority;

@class KTAbstractElement;

@interface KTAbstractDataSource : NSObject
{
    
}

+ (KTAbstractDataSource *)highestPriorityDataSourceForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex isCreatingPagelet:(BOOL)isCreatingPagelet;
+ (int) numberOfItemsToProcessDrag:(id <NSDraggingInfo>)draggingInfo;
+ (void) doneProcessingDrag;
- (void) doneProcessingDrag;

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;

/*! returns KTSourcePriorty for draggingPasteboard */
- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;

- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)sender;

- (NSString *)pageBundleIdentifier;
- (NSString *)pageletBundleIdentifier;

@end
