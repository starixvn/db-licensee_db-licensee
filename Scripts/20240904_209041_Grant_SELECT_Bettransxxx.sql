/*<info serverAlias="DBACC-bodb02"></info>*/

/*
	Created: 20240904@Bobby
	DB: DBACC-bodb02
	Task: #209041 - LAP - Licensee API - Get member balance/winloss
*/
use bodb02;

GRANT SELECT ON bettrans to [wsv_lap];
GO
GRANT SELECT ON bettransLC to [wsv_lap];
GO
GRANT SELECT ON bettransRNG to [wsv_lap];