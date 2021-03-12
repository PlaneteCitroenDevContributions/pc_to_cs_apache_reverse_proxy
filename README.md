https://stackoverflow.com/questions/14078426/login-to-site-with-curl-in-vbulletin

https://gist.github.com/saltun/0490cdd8598dce10831e




action="login.php?do=login" 
"vb_login_username" 
"vb_login_password" 
"s" value="" />
"securitytoken" value="guest" />
"do" value="login" />
"vb_login_md5password" />
"vb_login_md5password_utf" />


=== CHARLES

POST /forum/login.php?s=ee729e56aa973796471ea6a38f9f0dd7&do=login HTTP/1.1


vb_login_username=bernhara&vb_login_password=&vb_login_password_hint=Mot+de+passe&s=ee729e56aa973796471ea6a38f9f0dd7&securitytoken=guest&do=login&vb_login_md5password=a5f24cb6f1ea794692837ee263f7399f&vb_login_md5password_utf=a5f24cb6f1ea794692837ee263f7399f

