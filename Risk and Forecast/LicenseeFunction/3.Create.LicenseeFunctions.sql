USE [bodb_Licensee]
GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_LicenseeFunctions_LicenseeId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LicenseeFunctions] DROP CONSTRAINT [DF_LicenseeFunctions_LicenseeId]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_LicenseeFunctions_FunctionId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LicenseeFunctions] DROP CONSTRAINT [DF_LicenseeFunctions_FunctionId]
END

GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[LicenseeFunctions]    Script Date: 12/12/2011 16:04:56 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LicenseeFunctions]') AND type in (N'U'))
DROP TABLE [dbo].[LicenseeFunctions]
GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[LicenseeFunctions]    Script Date: 12/12/2011 16:04:56 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LicenseeFunctions](
	[LicenseeFunctionId] [int] IDENTITY(1,1) NOT NULL,
	[LicenseeId] [int] NOT NULL,
	[FunctionId] [int] NOT NULL,
 CONSTRAINT [PK_LicenseeFunctions] PRIMARY KEY CLUSTERED 
(
	[LicenseeFunctionId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [Licensee_table]
) ON [Licensee_table]

GO

ALTER TABLE [dbo].[LicenseeFunctions] ADD  CONSTRAINT [DF_LicenseeFunctions_LicenseeId]  DEFAULT ((0)) FOR [LicenseeId]
GO

ALTER TABLE [dbo].[LicenseeFunctions] ADD  CONSTRAINT [DF_LicenseeFunctions_FunctionId]  DEFAULT ((0)) FOR [FunctionId]
GO


GRANT SELECT ON [dbo].[LicenseeFunctions] TO [bodbLicenseeNet] 

GO