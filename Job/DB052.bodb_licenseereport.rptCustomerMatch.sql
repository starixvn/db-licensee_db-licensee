USE bodb_LicenseeReport
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: Customer in Match
	Date: 2014-02-12
	DB: DB052.bodb_licenseereport  
	Original: 
	Revision:	
	Parameter's Explanation:
			
*/
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptCustomerMatchData
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptCustomerMatchIndex
go
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptCustomerMatchData', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptCustomerMatchData.ndf', SIZE =100MB,MAXSIZE=UNLIMITED,FILEGROWTH=50MB)
TO FILEGROUP rptCustomerMatchData
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptCustomerMatchIndex', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptCustomerMatchIndex.ndf', SIZE =50MB,MAXSIZE=UNLIMITED,FILEGROWTH=30MB)
TO FILEGROUP rptCustomerMatchIndex
go


CREATE TABLE dbo.rptCustomerMatch(
	custid int NOT NULL,	
	matchid INT null,
	oddsid int null,
	Leagueid INT NULL,
	bettype smallint null,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,			
	stake money null,
	winlost	money null,	
	winlostdate datetime null,
	awinlost money null,
	comm money NULL,
	playercomm money NULL,
	recommend int NULL,
	isBA bit null,
	betcount smallint null
)
ON rptCustomerMatchData

GO
SET ANSI_PADDING OFF
GO 
GRANT SELECT ON dbo.rptCustomerMatch TO bodbLicenseeNet AS dbo
GO 
GRANT VIEW DEFINITION ON dbo.rptCustomerMatch TO vnteam AS dbo
GO

CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerMatch
(
	winlostdate desc
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

CREATE NONCLUSTERED INDEX IX_recommend ON [dbo].[rptCustomerMatch]
(
	recommend ASC,
	matchid DESC
)
INCLUDE ( 	custid,Leagueid)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON rptCustomerMatchIndex
GO

--drop table bodb_licenseereport.dbo.rptCustomerMatch