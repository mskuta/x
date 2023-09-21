// SPDX-License-Identifier: Unlicense

/* How to install (on Debian and derivatives):
 *   1. apt-get -y install libmariadb-dev
 *   2. cc $(mariadb_config --cflags) -ocheck_mysql_slave_channel check_mysql_slave_channel.c $(mariadb_config --libs)
 *   3. install -D -s -t/usr/local/lib/nagios/plugins check_mysql_slave_channel
 */

#define _GNU_SOURCE        // expose asprintf() in glibc
#define _POSIX_C_SOURCE 2  // expose getopt() in glibc
#include <err.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <mysql.h>

bool streq(const char* s1, const char* s2) {
	return strcmp(s1, s2) == 0;
}

int main(int argc, char* argv[]) {
	enum { STATE_OK, STATE_WARNING, STATE_CRITICAL, STATE_UNKNOWN } state = STATE_UNKNOWN;
	char* text = "?";
	bool wrongusage = false;
	char* opt_H = NULL;
	unsigned int opt_P = 0;
	char* opt_C = NULL;
	char* opt_u = NULL;
	char* opt_p = NULL;
	int opt_w = -1;
	int opt_c = -1;
	int ch;
	while ((ch = getopt(argc, argv, "H:P:C:u:p:w:c:h")) != -1)
		switch (ch) {
			case 'H':
				opt_H = optarg;
				break;
			case 'P':
				opt_P = atoi(optarg);
				break;
			case 'C':
				opt_C = optarg;
				break;
			case 'u':
				opt_u = optarg;
				break;
			case 'p':
				opt_p = optarg;
				break;
			case 'w':
				opt_w = atoi(optarg);
				break;
			case 'c':
				opt_c = atoi(optarg);
				break;
			case 'h': {
				extern char* __progname;
				char* basename;
				if ((basename = strrchr(__progname, '/')) == NULL)
					basename = __progname;
				else
					basename++;
				printf("Usage:\n"
				       "  %s [-H HOSTNAME] [-P PORTNUMBER] -C CHANNEL [-u USERNAME] [-p PASSWORD] -w SECONDS -c SECONDS\n"
				       "  %s -h\n"
				       "Options:\n"
				       "  -H  Host of the database server to connect to.\n"
				       "  -P  TCP/IP port to use for the connection.\n"
				       "  -C  Name of channel in multi-source replication.\n"
				       "\n"
				       "  -u  User to use when connecting to the database server.\n"
				       "  -p  Password to use when connecting to the database server.\n"
				       "\n"
				       "  -w  Gap between slave and master above which a WARNING status is indicated.\n"
				       "  -c  Gap between slave and master above which a CRITICAL status is indicated.\n"
				       "\n"
				       "  -h  Produce this text.\n",
				       basename,
				       basename);
				return STATE_OK;
			}
			default:
				wrongusage = true;
		}
	argc -= optind;
	argv += optind;
	if (argc != 0)
		wrongusage = true;
	if (opt_C == NULL || opt_w < 0 || opt_c < 0 || opt_w > opt_c)
		wrongusage = true;
	if (!wrongusage) {
		// Resources allocated by functions from libmariadb are
		// released explicitly to avoid leaving any remnants on the
		// server. Resources from libc, on the other hand, are not,
		// since this program creates only a short-lived process.
		if (mysql_library_init(0, NULL, NULL) == 0) {
			MYSQL* mysql = mysql_init(NULL);
			if (mysql != NULL) {
				if (mysql_real_connect(mysql, opt_H, opt_u, opt_p, NULL, opt_P, NULL, 0) != NULL) {
					const char* server_name = strdup(mysql_get_server_name(mysql));
					if (server_name != NULL) {
						if (streq(server_name, "MySQL") || streq(server_name, "MariaDB")) {
							char* stmt_fmt;
							if (streq(server_name, "MySQL"))
								stmt_fmt = "SHOW SLAVE STATUS FOR CHANNEL '%s'";
							else  // "MariaDB"
								stmt_fmt = "SHOW SLAVE '%s' STATUS";

							char* stmt_str;
							const int stmt_len = asprintf(&stmt_str, stmt_fmt, opt_C);
							if (stmt_len != -1) {
								if (mysql_real_query(mysql, stmt_str, stmt_len) == 0) {
									MYSQL_RES* res = mysql_use_result(mysql);
									if (res != NULL) {
										// the SHOW statement above returns one row at most
										MYSQL_ROW row = mysql_fetch_row(res);
										if (row != NULL) {
											const unsigned int num_fields = mysql_num_fields(res);
											MYSQL_FIELD* fields = mysql_fetch_fields(res);
											for (unsigned int i = 0; i < num_fields; i++) {
												if (streq(fields[i].name, "Seconds_Behind_Master") && row[i] != NULL) {
													const int gap = atoi(row[i]);
													state = (gap > opt_c) ? STATE_CRITICAL : ((gap > opt_w) ? STATE_WARNING : STATE_OK);
													if (asprintf(&text, "%d seconds behind master", gap) == -1)
														text = "No info available";
												}
												else if (streq(fields[i].name, "Slave_IO_Running")) {
													if (streq(row[i], "No")) {
														text = "I/O thread is not running";
														state = STATE_CRITICAL;
													}
													else if (streq(row[i], "Connecting")) {
														text = "I/O thread is running but not connected";
														state = STATE_CRITICAL;
													}
												}
												else if (streq(fields[i].name, "Slave_SQL_Running")) {
													if (streq(row[i], "No")) {
														text = "SQL thread is not running";
														state = STATE_CRITICAL;
													}
												}
												if (state == STATE_WARNING || state == STATE_CRITICAL)
													break;
											}
										}
										else {
											if (mysql_errno(mysql) == 0)
												text = "Channel not found";
											else {
												if (asprintf(&text, "mysql_fetch_row() failed: ERROR %d: %s", mysql_errno(mysql), mysql_error(mysql)) == -1)
													text = "mysql_fetch_row() failed";
											}
										}
										mysql_free_result(res);
									}
									else {
										if (asprintf(&text, "mysql_use_result() failed: ERROR %d: %s", mysql_errno(mysql), mysql_error(mysql)) == -1)
											text = "mysql_use_result() failed";
									}
								}
								else {
									if (asprintf(&text, "mysql_query() failed: ERROR %d: %s", mysql_errno(mysql), mysql_error(mysql)) == -1)
										text = "mysql_query() failed";
								}
							}
							else
								text = "SQL statement could not be generated";
						}
						else {
							if (asprintf(&text, "Database server unknown: %s", server_name) == -1)
								text = "Database server unknown";
						}
					}
					else
						text = "Database server could not be determined";
				}
				else {
					if (asprintf(&text, "mysql_real_connect() failed: ERROR %d: %s", mysql_errno(mysql), mysql_error(mysql)) == -1)
						text = "mysql_real_connect() failed";
				}
				mysql_close(mysql);
			}
			else
				text = "mysql_init() failed";
			mysql_library_end();
		}
		else
			text = "mysql_library_init() failed";
	}
	else
		text = "Usage wrong";

	const char* state_text[] = { "OK", "WARNING", "CRITICAL", "UNKNOWN" };
	printf("%s - %s\n", state_text[state], text);
	return state;
}

// vim: ts=8 sts=0 sw=8 noet
