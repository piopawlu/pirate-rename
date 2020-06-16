/***************************************************************************
 PirateRenameAppDelegate.h 
 -------------------
 begin                : 2010-01-24
 copyright            : (C) 2010 Piotr Pawluczuk
 email                : *******@piopawlu.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License           *
 *   version 2.1 as published by the Free Software Foundation;             *
 *                                                                         *
 ***************************************************************************/

#import <Cocoa/Cocoa.h>
#import "ftdi.h"

// struct libusb_device;
// struct ftdi_context;
// struct ftdi_context;

@interface PirateRenameAppDelegate : NSObject
{
    NSWindow *window;
	
	IBOutlet NSButton *btn_read;
	IBOutlet NSButton *btn_write;
	IBOutlet NSButton *btn_close;
	IBOutlet NSButton *btn_update;
	IBOutlet NSButton *btn_suggest;
	IBOutlet NSComboBox *ftdi_combo;
	
	IBOutlet NSTextField *ftdi_manufacturer;
	IBOutlet NSTextField *ftdi_description;
	IBOutlet NSTextField *ftdi_serial;
	IBOutlet NSTextField *ftdi_dev_path;
	
	long button_state;
	libusb_device* ftdi_list[16];
	struct ftdi_eeprom  eeprom;
	struct ftdi_context ftdi;
	Boolean ftdi_drivers_checked;
	unsigned char original_eeprom_buffer[FTDI_DEFAULT_EEPROM_SIZE];
}

@property (assign) IBOutlet NSWindow *window;

-(IBAction)updateButtonClicked:(id)sender;
-(IBAction)closeButtonClicked:(id)sender;
-(IBAction)readButtonClicked:(id)sender;
-(IBAction)writeButtonClicked:(id)sender;
-(IBAction)setDefaults:(id)sender;

-(void)notificationReceived:(NSNotification*)n;
-(void)saveButtonStateAndDisable;
-(void)restoreButtonState;
-(int)checkFTDIdrivers;
-(int)buildNewEEPROM:(unsigned char*)eeprom_buf withManufacturer: (const char*)manufacturer withProduct: (const char*)product andSerial: (const char*)serial;
-(void)backupRawEEPROM;

-(NSApplicationTerminateReply)applicationShouldTerminate: (NSApplication *)app;

@end
