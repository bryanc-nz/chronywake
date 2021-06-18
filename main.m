//
//  main.m
//  chronywake
//
//  Created by Bryan Christianson on 7/06/21.
//

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>

@import AppKit;

static const char *chronyc = "/usr/local/bin/chronyc";

/* makestep args */
static double g_makestep_thresh = 0.1;
static int g_makestep_limit = 3;

/* burst args */
static int g_burst_good = 4;
static int g_burst_max = 4;
static const char *g_burst_mask = "";

static int g_singleshot = 0;

static void usage_exit()
{
	printf("chronywake, by default, waits for a DidWakeNotification from macOS. On awakening, the\n");
	printf("following commands are run (as root) to synchronise the system clock:\n");
	printf("\n");
	printf("chronyc makestep 0.1 3\n");
	printf("chronyc burst 4/4 [optional netmask]\n");
	printf("\n");
	printf("For further detail, refer to the entries for 'makestep' and 'burst' in the chronyc man page.\n");
	printf("The -n option causes chronywake to execute the commands a single time and then exit.\n");
	printf("The -h option displays this help text and then exits.\n");
	printf("\n");
	printf("Usage:\n");
	printf("chronywake [options]\n");
	printf("options: [-c path-to-chronyc]\n");
	printf("         [-g burst-good]\n");
	printf("         [-h]\n");
	printf("         [-l makestep-limit]\n");
	printf("         [-m burst-max]\n");
	printf("         [-n netmask]\n");
	printf("         [-s]\n");
	printf("         [-t makestep-threshold]\n");
	exit(1);
}

static void getoptions(int argc, char *argv[])
{
	int ch;
	struct stat statbuf;

	while ((ch = getopt(argc, argv, "c:g:hl:m:n:st:")) != -1) {
		switch (ch) {
		case 'c':
			chronyc = optarg;
			break;

		case 'g':
			{
				int val = atoi(optarg);
				if (val <= 0) {
					NSLog(@"Invalid burst 'good' count: %d", val);
					usage_exit();
				}
				g_burst_good = val;
			}
			break;

		case 'h':
			usage_exit();
			break;

		case 'l':
			{
				int val = atoi(optarg);
				if (val <= 0) {
					NSLog(@"Invalid makestep 'limit' count: %d", val);
					usage_exit();
				}
				g_makestep_limit = val;
			}
			break;

		case 'm':
			{
				int val = atoi(optarg);
				if (val <= 0) {
					NSLog(@"Invalid burst 'max' count: %d", val);
					usage_exit();
				}
				g_burst_max = val;
			}
			break;

		case 'n':
			g_burst_mask = optarg;
			break;

		case 's':
			g_singleshot = 1;
			break;

		case 't':
			{
				double val = atof(optarg);
				if (val <= 0) {
					NSLog(@"Invalid makestep 'threshold' count: %f", val);
					usage_exit();
				}
				g_makestep_thresh = val;
			}
			break;

		default:
			NSLog(@"Unknown option: %c", ch);
			usage_exit();
			break;
		}
	}

	if (stat(chronyc, &statbuf) != 0) {
		NSLog(@"No file at: %s", chronyc);
		usage_exit();
	}

	if (statbuf.st_uid != 0) {
		NSLog(@"File must be owned by root: %s", chronyc);
		usage_exit();
	}

	if ((statbuf.st_mode & S_IXUSR) == 0) {
		NSLog(@"File must be executable: %s", chronyc);
		usage_exit();
	}
}

static void didWake(void)
{
	char cmd[1024];
	char *p = cmd;

	NSLog(@"System has woken up - sync chronyd");

	p += snprintf(p, sizeof(cmd), "%s makestep %f %d", chronyc, g_makestep_thresh, g_makestep_limit);
	NSLog(@"%s", cmd);
	system(cmd);

	p = cmd;
	p += snprintf(p, sizeof(cmd), "%s burst %d/%d", chronyc, g_burst_good, g_burst_max);
	if (strlen(g_burst_mask) > 0) {
		p += snprintf(p, sizeof(cmd) - strlen(cmd), " %s", g_burst_mask);
	}
	NSLog(@"%s", cmd);
	system(cmd);

	snprintf(cmd, sizeof(cmd), "%s makestep", chronyc);
	NSLog(@"%s", cmd);
	system(cmd);
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
	    NSLog(@"Starting chrony wakeup daemon...");

		if (geteuid() != 0) {
			NSLog(@"chronywake must be run as root");
			usage_exit();
		}

	    getoptions(argc, argv);

	    if (g_singleshot) {
			didWake();
	    } else {
			NSNotificationCenter *notificationCenter = NSWorkspace.sharedWorkspace.notificationCenter;
			[notificationCenter	addObserverForName: NSWorkspaceDidWakeNotification
											object: nil
											 queue: nil
										usingBlock: ^void(NSNotification *note){ (void)note; didWake(); }
			];

			NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
			[ currentRunLoop run ];
		}
	}

	NSLog(@"Finished chrony wakeup daemon...");
	return 0;
}
