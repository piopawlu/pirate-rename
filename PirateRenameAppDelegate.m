/***************************************************************************
 PirateRenameAppDelegate.m 
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

#include <stdint.h>
#import "PirateRenameAppDelegate.h"

@implementation PirateRenameAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	if( ftdi_init(&ftdi) < 0 ) {
		
		NSRunAlertPanel( @"Initialization error", @"Could not initialize libftdi!", @"OK", nil, nil);
	}
	
	ftdi_drivers_checked = false;
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(notificationReceived:) name:NSComboBoxSelectionDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(notificationReceived:) name:NSControlTextDidChangeNotification object:nil]; 
	
}

-(NSApplicationTerminateReply)applicationShouldTerminate: (NSApplication *)app
{
	
	ftdi_deinit(&ftdi);
	
	return NSTerminateNow;
}

-(void)notificationReceived:(NSNotification*)n
{
	if( [n name] == NSComboBoxSelectionDidChangeNotification) {
		
		[ftdi_serial setEnabled:NO];
		[ftdi_serial setStringValue: @""];
		
		[ftdi_manufacturer setEnabled:NO];
		[ftdi_manufacturer setStringValue: @""];
		
		[ftdi_description setEnabled:NO];
		[ftdi_description setStringValue: @""];
		
		[btn_write setEnabled: NO];
		[btn_suggest setEnabled: NO];
		
	} else if ( [n name] == NSControlTextDidChangeNotification ) {
		
		if( [n object] == ftdi_serial)
		{
			NSUInteger serial_length = [[ftdi_serial stringValue] length];
			
			if ( serial_length > 8 || serial_length < 1 ) {
				[ftdi_serial setBackgroundColor: [NSColor colorWithDeviceRed:1.0f green:0.71f blue:0.75f alpha:1.0f]];
				[ftdi_dev_path setStringValue: [NSString stringWithCString: "/dev/tty.usbserial-????????" encoding:NSASCIIStringEncoding ]];
				[btn_write setEnabled: NO];
			} else {
				[ftdi_serial setBackgroundColor: [NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f]];
				[ftdi_dev_path setStringValue: [NSString stringWithFormat: @"/dev/tty.usbserial-%@", [ftdi_serial stringValue] ]];
				[btn_write setEnabled: YES];
			}
					 
		}
		
	}
}

-(void)saveButtonStateAndDisable
{
	button_state = 0;
	
	button_state |= 0x03; //close + refresh
	button_state |= ([btn_read isEnabled] == YES) ? 0x04 : 0;
	button_state |= ([btn_write isEnabled] == YES) ? 0x08 : 0;
	button_state |= ([btn_suggest isEnabled] == YES) ? 0x10 : 0;
	
	[btn_read setEnabled: NO];
	[btn_write setEnabled: NO];
	[btn_update setEnabled: NO];
	[btn_close setEnabled: NO];
	[btn_suggest setEnabled: NO];
}

-(void)restoreButtonState
{
	[btn_read setEnabled: (button_state & 0x04) ? YES : NO];
	[btn_write setEnabled: (button_state & 0x08) ? YES : NO];
	[btn_suggest setEnabled: (button_state & 0x10) ? YES : NO];
	
	[btn_update setEnabled: YES];
	[btn_close setEnabled: YES];
}

-(IBAction)setDefaults:(id)sender
{
	[ftdi_serial setStringValue: @"PirateV3"];
	[ftdi_manufacturer setStringValue: @"Dangerous Prototypes"];
	[ftdi_description setStringValue: @"Bus Pirate V3"];
	[ftdi_dev_path setStringValue: @"/dev/tty.usbserial-PirateV3"];
}

-(IBAction)updateButtonClicked:(id)sender
{
	char manufacturer[64], description[64], serial[64];
	struct ftdi_device_list* lst = NULL;
	int  num_added = 0;
	int  res = 0;
	
	[self saveButtonStateAndDisable];
	
	if( ftdi_drivers_checked == NO && [self checkFTDIdrivers] != 0 ) {
		goto Finished;
	}
	
	[ftdi_combo removeAllItems];
	
	if( (res = ftdi_usb_find_all(&ftdi, &lst, 0x0403, 0x6001)) > 0 )
	{

		for(struct ftdi_device_list* lptr = lst;
            lptr && lptr->dev && num_added < 16;
            lptr = lptr->next, ++num_added)
		{
			//char * manufacturer, int mnf_len, char * description, int desc_len, char * serial, int serial_len)
			ftdi_usb_get_strings(&ftdi, lptr->dev, manufacturer, sizeof(manufacturer)-1,
								 description, sizeof(description)-1, serial, sizeof(serial)-1);
			
			ftdi_list[num_added] = lptr->dev;
			
			[ftdi_combo addItemWithObjectValue: [NSString stringWithFormat: @"%s - %s", description, serial] ];
		}
		
		[ftdi_combo selectItemAtIndex:0];
	
		button_state |= 0x04;
		
		ftdi_list_free(&lst);
	}
	
	
Finished:
	[self restoreButtonState];
}

-(IBAction)closeButtonClicked:(id)sender
{
	[NSApp terminate:sender];
}

-(IBAction)readButtonClicked:(id)sender
{
	int res = 0;
	unsigned char eeprom_buf[FTDI_DEFAULT_EEPROM_SIZE] = {0};
	
	[self saveButtonStateAndDisable];
	
	res = ftdi_usb_open_dev(&ftdi, ftdi_list[ [ftdi_combo indexOfSelectedItem]]);
	
	if( res < 0 ) { 
		NSRunAlertPanel( @"Unable to claim USB device", @"Please make sure FTDI drivers are not loaded!", @"OK", nil, nil);
		goto Finished2;
	}
	
	res = ftdi_read_eeprom(&ftdi, eeprom_buf);
	if( res < 0 ) {
		NSRunAlertPanel( @"Unable to read EEPROM block", @"Please check connection and try again!", @"OK", nil, nil);
		goto Finished1;
	}
	
	memcpy(original_eeprom_buffer, eeprom_buf, FTDI_DEFAULT_EEPROM_SIZE);
	
	puts("EEPROM READ:");
	for( res=0; res<128; )
	{
		printf("%02x ", eeprom_buf[res]);
		if( (++res & 0x0F) == 0 && (res & 0xF0) ) {
			putchar('\n');
		}
	}
	
	res = ftdi_eeprom_decode(&eeprom, eeprom_buf, sizeof(eeprom_buf));
	
	if( res < 0 ) {
		NSRunAlertPanel( @"Unable to decode EEPROM block", @"Please check connection and try again!", @"OK", nil, nil);
		goto Finished1;
	}
	
	[ftdi_manufacturer setStringValue: [NSString stringWithCString: eeprom.manufacturer encoding:NSASCIIStringEncoding]];
	[ftdi_description setStringValue: [NSString stringWithCString: eeprom.product encoding:NSASCIIStringEncoding]];
	[ftdi_serial setStringValue: [NSString stringWithCString: eeprom.serial encoding:NSASCIIStringEncoding]];
	
	[ftdi_dev_path setStringValue: [NSString stringWithFormat: @"/dev/tty.usbserial-%s", eeprom.serial]];
	
	
	[ftdi_serial setEnabled:YES];
	[ftdi_manufacturer setEnabled:YES];
	[ftdi_description setEnabled:YES];
	
	button_state |= 0x18;
Finished1:
	ftdi_usb_close(&ftdi);
Finished2:
	[self restoreButtonState];
}

-(int)buildNewEEPROM:(unsigned char*)eeprom_buf withManufacturer: (const char*)manufacturer withProduct: (const char*)product andSerial: (const char*)serial
{
	unsigned char  i = 0, *uc;
	unsigned short checksum = 0, value = 0;
	
	//clone original eeprom
	memcpy(eeprom_buf, original_eeprom_buffer, FTDI_DEFAULT_EEPROM_SIZE);
	
	//zero string part
	memset(eeprom_buf + 0x18, 0, FTDI_DEFAULT_EEPROM_SIZE - 0x18);
	
	//set offsets
    eeprom_buf[0x0A] |= 0x08; //enable serial
    
	eeprom_buf[0x0E] = 0x18;
    eeprom_buf[0x0F] = strlen(manufacturer) * 2 + 2;
	
	eeprom_buf[0x10] = eeprom_buf[0x0E] + eeprom_buf[0x0F];
    eeprom_buf[0x11] = strlen(product) * 2 + 2;
	
	eeprom_buf[0x12] = eeprom_buf[0x10] + eeprom_buf[0x11];
    eeprom_buf[0x13] = strlen(serial) * 2 + 2;
	
	if( (eeprom_buf[0x12] + eeprom_buf[0x13]) >= (FTDI_DEFAULT_EEPROM_SIZE - 2) ) {
		return -1;
	}
	
	//write manufacturer
	uc = &eeprom_buf[eeprom_buf[0x0E]];
	uc[0] = eeprom_buf[0x0F]; //length
	uc[1] = 0x03; //string
	uc   += 2;
	for(i = 0; manufacturer[i]; i++, uc += 2) {
		*uc = manufacturer[i];
	}
	
	//write product
	uc = &eeprom_buf[eeprom_buf[0x10]];
	uc[0] = eeprom_buf[0x11]; //length
	uc[1] = 0x03; //string
	uc   += 2;
	for(i = 0; product[i]; i++, uc += 2) {
		*uc = product[i];
	}
	
	//write serial
	uc = &eeprom_buf[eeprom_buf[0x12]];
	uc[0] = eeprom_buf[0x13]; //length
	uc[1] = 0x03; //string
	uc   += 2;
	for(i = 0; serial[i]; i++, uc += 2) {
		*uc = serial[i];
	}
	
	// fix offsets
	eeprom_buf[0x0E] |= 0x80;
	eeprom_buf[0x10] |= 0x80;
	eeprom_buf[0x12] |= 0x80;
	
	// repair checksum
    checksum = 0xAAAA;
	
    for (i = 0; i < (FTDI_DEFAULT_EEPROM_SIZE/2) - 1; i++)
    {
        value  = eeprom_buf[i*2];
        value |= eeprom_buf[(i*2)+1] << 8;
		
        checksum = value^checksum;
        checksum = (checksum << 1) | (checksum >> 15);
    }
	
    eeprom_buf[FTDI_DEFAULT_EEPROM_SIZE - 2] = checksum;
    eeprom_buf[FTDI_DEFAULT_EEPROM_SIZE - 1] = checksum >> 8;
	
	return 0;
}

-(void)backupRawEEPROM
{
	NSString* fileName = nil;
	char szFileName[512] = {0};
	FILE* fp = NULL;

	NSSavePanel* saveDlg = [NSSavePanel savePanel];

	if ( [saveDlg runModalForDirectory:nil file:@"backup.eep"] == NSOKButton )
	{
		fileName = [saveDlg filename];
		
		[fileName getCString: szFileName maxLength: (sizeof(szFileName) - 1) encoding: NSASCIIStringEncoding];
		
		if( (fp = fopen(szFileName, "wb")) ) {
			fwrite(original_eeprom_buffer, sizeof(original_eeprom_buffer), 1, fp);
			fclose(fp);
		}
	}
	
}

-(IBAction)writeButtonClicked:(id)sender
{
	int  res = 0;
	char manufacturer[64];
	char serial[64];
	char description[64];
	unsigned char eeprom_buf[FTDI_DEFAULT_EEPROM_SIZE];
	struct ftdi_eeprom tmpeep = {0};
	
	[self saveButtonStateAndDisable];
	
	[[ftdi_description stringValue] getCString: description maxLength: (sizeof(description) - 1) encoding:NSASCIIStringEncoding];
	[[ftdi_manufacturer stringValue] getCString: manufacturer maxLength: (sizeof(manufacturer) - 1) encoding:NSASCIIStringEncoding];
	[[ftdi_serial stringValue] getCString: serial maxLength: (sizeof(serial) - 1) encoding:NSASCIIStringEncoding];
	
	//build new EEPROM
	
	res = [self buildNewEEPROM:eeprom_buf withManufacturer:manufacturer withProduct:description andSerial:serial];
	
	if( res < 0 ) {
		NSRunAlertPanel( @"Unable to rebuild EEPROM", @"Sum of all string lengths must not exceed 40 characters", @"OK", nil, nil);
		goto Finished2;
	}
	
	//verify new EEPROM
	res = ftdi_eeprom_decode(&tmpeep, eeprom_buf, FTDI_DEFAULT_EEPROM_SIZE);
	
	if( res < 0 )  {
		NSRunAlertPanel( @"Oops, self-check error",
						@"Don't worry, no write operation took place, please tell us what information was entered in the form to generate this error", @"OK", nil, nil);
		goto Finished2;
	}
	
	res = NSRunAlertPanel(@"Would you like a RAW EEPROM backup?", 
						  @"RAW backup may be useful if the EEPROM write operation fails. This is very unlikely, but it's always reasonable to have a backup." ,
						  @"Yes", @"Cancel", @"No");
	
	if( res == NSAlertAlternateReturn || res == NSAlertErrorReturn) {
		goto Finished2;
	} else if ( res == NSAlertDefaultReturn ) {
		[self backupRawEEPROM];
	}
	
	res = ftdi_usb_open_dev(&ftdi, ftdi_list[ [ftdi_combo indexOfSelectedItem]]);
	
	if( res < 0 ) {
		NSRunAlertPanel( @"Unable to claim USB device", @"Please make sure FTDI drivers are not loaded!", @"OK", nil, nil);
		goto Finished2;
	}
	
	puts("EEPROM WRITE:");
	for( res=0; res<128; ) {
		
		printf("%02x ", eeprom_buf[res]);
		if( (++res & 0x0F) == 0 && (res & 0xF0) ) {
			putchar('\n');
		}
	}
	
	res = ftdi_write_eeprom(&ftdi, eeprom_buf);
	
	if( res < 0 ) {
		NSRunAlertPanel( @"Could not write EEPROM", [NSString stringWithFormat: @"Writing EEPROM failed with following result code: %d", res], @"OK", nil, nil);
	} else {
		NSRunAlertPanel( @"EEPROM successfully written!", @"Please reconnect your device and go to System Profiler to confirm successful operation :)", @"OK", nil, nil);
	}
	
	
Finished1:
	ftdi_usb_close(&ftdi);
Finished2:
	[self restoreButtonState];
}

-(int)checkFTDIdrivers
{
	char line[256] = {0};
	FILE* p = popen("kextstat -l | grep FTDI", "r");
	
	if( p ) {
		
		while( !feof(p) && fgets(line, sizeof(line), p) ) {
			break;
		}
		pclose(p);
		
		if( line[0] != 0 ) {
			NSRunAlertPanel( @"FTDI Kernel module is active", @"Kextstat found FTDIUSBSerialDriver.kext active, please unload it with kextunload and try again", @"OK", nil, nil);
			return -1;
		}
	} else {
		printf("popen failed, errno = %d\n", errno);
		return -1;
	}
	
	ftdi_drivers_checked = YES;
	return 0;
}

@end

