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
	Task: List Customer in Match
	Date: 2014-02-12
	DB: DB052.bodb_licenseereport
	Original: 
	Revision:	
	Parameter's Explanation:
			
*/
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptListCustomerMatchData
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptListCustomerMatchIndex
go
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptListCustomerMatchData', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptListCustomerMatchData.ndf', SIZE =100MB,MAXSIZE=UNLIMITED,FILEGROWTH=50MB)
TO FILEGROUP rptListCustomerMatchData
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptListCustomerMatchIndex', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptListCustomerMatchIndex.ndf', SIZE =50MB,MAXSIZE=UNLIMITED,FILEGROWTH=30MB)
TO FILEGROUP rptListCustomerMatchIndex
go


CREATE TABLE dbo.rptListCustomerMatch(
	custid int NOT NULL,	
	matchid INT null,
	leagueid int null,
	bettype smallint null,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,			
	stake money null,
	winlost	money null,	
	winlostdate datetime null,
	AmtDueToBA money null,
	BAComm money null,
	recommend int NULL,
	isBA bit null,
	betcount smallint null
)
ON rptListCustomerMatchData

GO
SET ANSI_PADDING OFF
GO 
GRANT SELECT ON dbo.rptListCustomerMatch TO bodbLicenseeNet AS dbo
GO 
GRANT VIEW DEFINITION ON dbo.rptListCustomerMatch TO vnteam AS dbo
GO

CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptListCustomerMatch
(
	winlostdate desc
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

CREATE NONCLUSTERED INDEX IX_recommend ON dbo.rptListCustomerMatch
(
	recommend asc,
	custid asc,
	matchid ASC	
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
on rptListCustomerMatchIndex
GO

--drop table bodb_licenseereport.dbo.rptListCustomerMatch