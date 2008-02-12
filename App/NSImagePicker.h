/*
 *     Derrived from the ourput of class-dump (version 2.1.5).
 *     class-dump is Copyright (C) 1997, 1999, 2000, 2001 by Steve Nygard.

 *                       ****** WARNING !!!! ******
 *
 * This set of classes is not documented by Apple, and as such there is
 * absolutely no guarantee that it will not change!  There are clear signs
 * that the API was never expected to be used by third parties in its current
 * form.
 *
 *                 ****** USE AT YOUR OWN RISK !!!! ******

 * Refers to parts of file: /System/Library/Frameworks/AddressBook.framework/AddressBook and
 * .../AddressBook.framework/ImagePickerQTParts.bundle/Contents/MacOS/ImagePickerQTParts
 */

#import <AppKit/AppKit.h>

// This is defined as a protcol for documentation reasons; it's not really necessary to have it so
@protocol ApparentlyNSImagePickerDelegateProtocol

// This gets called when the user selects OK on a new image
- (void)imagePicker: (id) sender selectedImage: (NSImage *) image;

// This is called if the user cancels an image selection
- (void)imagePickerCanceled: (id) sender;

// This is called to provide an image when the delegate is first set and
// following selectionChanged messages to the controller.
// The junk on the end seems to be the selector name for the method itself
- (NSImage *) displayImageInPicker: junk;

// This is called to give a title for the picker.  It is called as above.
// Note that you must not return nil
- (NSString *) displayTitleInPicker: junk;
@end

@interface NSImagePickerController:NSWindowController
{
@private
    id _imageView;
    id *_layerSuperview;
    NSSlider *_slider;
    id *_recentMenu;
    NSButton *_cameraButton;
    NSButton *_smallerButton;
    NSButton *_largerButton;
    NSButton *_chooseButton;
    NSButton *_setButton;
    NSImage *_originalImage;
    struct _NSSize _originalSize;
    struct _NSSize _targetSize;
    struct _NSSize _minSize;
    struct _NSSize _maxSize;
    float _defaultSliderPos;
    id *_recentPicture;
    char _changed;
    char _changesAccepted;
    char _takingPicture;
    id _target;
    SEL _action;
    void *_userInfo;
    id _delegate;
}

// This seems to be the best way to get the Image Picker to use
+ (NSImagePickerController *) sharedImagePickerControllerCreate: (BOOL) create;

// This is the pop-up for the recently presented pictures
+ recentPicturesPopUp;

// The point given is NOT taken within the context of the window!
- initAtPoint:(NSPoint) p inWindow: w;

// Don't use this method! Implement imagePicker:selectedImage: and imagePickerCanceled: instead
// This target here can't work out if the user hit Cancel
- (void)setTarget: onObject selector:(SEL) aSelector userInfo:(void *) context;

// Get the image back
- image;

// Get back the image that was there before
- originalImage;

// Set the delegate
- (void)setDelegate: anObject;

// Notify the controller that the selection for which we are setting the image
// has changed.  This causes the delegate to be asked for a new image and title
- (void)selectionChanged;


- (void)hideRecentsPopUp;

@end

@interface NSImagePickerController(QTImagePickerBundle)
// Get information about the inner bundle
+ bundle;

// Get/Set if the user has changed anything in the dialoge
- (void)setHasChanged: (BOOL) changed;
- (BOOL)hasChanged;

- (void)handlePictureTakenNotification: (NSNotification *) aNotification;

// You need to call this when you get notification that a cammera has been (un)plugged
- (void)_updateCameraButton;

// Set the image to be displayed.  Useful for the initial image, or you can implement displayImageInPicker:
- (void)setWidgetImage: (NSImage *) anImage;

// Get and set the cropping rectangle
- (NSRect)crop;
- (void)setCrop: (NSRect) aRect;


// The remaining methods are ones that are not obviously standard methods or actions for the panel
// but which I've not yet work out

// Fakes OK and Cancel
- (void)sendChangesToOwner;
- (void)sendCancelToOwner;

// Handles information pertaining to the recent pictures list
- (void)setRecentPicture:fp8;
- recentPicture;

- (void)setViewImage:(NSSize)fp8;

@end
