//
//  KTDraggingInfo.h
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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


@interface KTDraggingInfo : NSObject <NSDraggingInfo>
{
    NSImage *myDraggedImage;
    NSPoint myDraggedImageLocation;
    NSWindow *myDraggingDestinationWindow;
    NSPoint myDraggingLocation;
    NSPasteboard *myDraggingPasteboard;
    int myDraggingSequenceNumber;
    id myDraggingSource;
    NSDragOperation myDraggingSourceOperationMask;
}

+ (KTDraggingInfo *)draggingInfoWithDraggingInfo:(id <NSDraggingInfo>)info;
+ (KTDraggingInfo *)draggingInfoWithDraggingInfo:(id <NSDraggingInfo>)info pbaord:(NSPasteboard *)aPboard;

- (void)setDraggedImage:(NSImage *)anImage;
- (NSImage *)draggedImage;

- (void)setDraggedImageLocation:(NSPoint)aLocation;
- (NSPoint)draggedImageLocation;

- (void)setDraggingDestinationWindow:(NSWindow *)aWindow;
- (NSWindow *)draggingDestinationWindow;

- (void)setDraggingLocation:(NSPoint)aLocation;
- (NSPoint)draggingLocation;

- (void)setDraggingPasteboard:(NSPasteboard *)aPboard;
- (NSPasteboard *)draggingPasteboard;

- (void)setDraggingSequenceNumber:(int)anInt;
- (int)draggingSequenceNumber;

- (void)setDraggingSource:(id)anObject;
- (id)draggingSource;

- (void)setDraggingSourceOperationMask:(NSDragOperation)anOperationMask;
- (NSDragOperation)draggingSourceOperationMask;

/*! these are effectively no-ops and shouldn't be called */
- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination;
- (void)slideDraggedImageTo:(NSPoint)aPoint;

@end
