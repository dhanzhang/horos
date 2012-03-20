/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/


@class ThreadsManagerThreadInfo;

@interface ThreadModalForWindowController : NSWindowController {
	NSThread* _thread;
    id _retainedThreadDictionary;
	NSWindow* _docWindow;
	NSProgressIndicator* _progressIndicator;
	NSButton* _cancelButton;
	NSTextField* _titleField;
	NSTextView* _statusField;
    NSScrollView* _statusFieldScroll;
	NSTextField* _progressDetailsField;
    CGFloat _lastDisplayedStatus;
}

@property(retain, readonly) NSThread* thread;
@property(retain, readonly) NSWindow* docWindow;
@property(retain) IBOutlet NSProgressIndicator* progressIndicator;
@property(retain) IBOutlet NSButton* cancelButton;
@property(retain) IBOutlet NSTextField* titleField;
@property(retain) IBOutlet NSTextView* statusField;
@property(retain) IBOutlet NSScrollView* statusFieldScroll;
@property(retain) IBOutlet NSTextField* progressDetailsField;

-(id)initWithThread:(NSThread*)thread window:(NSWindow*)window;

-(IBAction)cancelAction:(id)source;

-(void)invalidate;

@end


@interface NSThread (ModalForWindow)

-(ThreadModalForWindowController*)startModalForWindow:(NSWindow*)window; // returns nil if not called on main thread
-(ThreadModalForWindowController*)modalForWindowController;

@end;