use [bodb02]
grant select on dbo.BalanceRecord to bodbLicenseeNet
GO
grant select on dbo.BalanceRecord to bodbDownlineNet
GO

use BalanceRecord
go
CREATE USER bodbLicenseeNet FOR LOGIN bodbLicenseeNet;  
GO
CREATE USER bodbDownlineNet FOR LOGIN bodbDownlineNet;  
GO

grant select on dbo.BalanceRecord_bk to bodbLicenseeNet
GO
grant select on dbo.BalanceRecord_bk to bodbDownlineNet
GO