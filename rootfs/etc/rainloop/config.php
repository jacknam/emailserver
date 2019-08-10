<?php
$_ENV['RAINLOOP_INCLUDE_AS_API'] = true;
include '/etc/rainloop/public/index.php';
$oConfig = \RainLoop\Api::Config();
$oConfig->Save();
?>
