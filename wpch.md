# Description

wpch consists of several programs that can be used to change the configuration of a WordPress site from the command line.


# Usage

Credentials to access the database do not have to be specified. They are taken from the file `wp-config.php`, which is part of every WordPress installation.

## wpchemail

wpchemail changes the administrator's email address without the need for verification.

```
Usage:
  wpchemail [-d DIRECTORY]
  wpchemail [-d DIRECTORY] ADDRESS
Options:
  -d  Directory containing the WordPress files.

If no DIRECTORY is specified, the current one will be used.
If no argument is specified, just the active settings will be displayed.
```

## wpchurl

wpchurl changes the location at which a site should be reachable. It automates the steps described [here](https://wordpress.org/support/article/changing-the-site-url/#changing-the-url-directly-in-the-database "Changing the URL directly in the database") on the official WordPress website.

```
Usage:
  wpchurl [-d DIRECTORY]
  wpchurl [-d DIRECTORY] [-HS] URL
Options:
  -d  Directory containing the WordPress files.
  -H  Do not change the WordPress Address ("home").
  -S  Do not change the Site Address ("siteurl").

If no DIRECTORY is specified, the current one will be used.
If no argument is specified, just the active settings will be displayed.
```

### Examples

Display the current settings for "Site Address" and "WordPress Address":
```shell
wpchurl -d /var/www/mysite
```

Set both addresses to a different value:
```shell
wpchurl -d /var/www/mysite https://www.newname.com
```


