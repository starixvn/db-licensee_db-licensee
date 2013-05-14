USE [bodb_Licensee]
GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_LicenseeUserFunction_UserId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LicenseeUserFunctions] DROP CONSTRAINT [DF_LicenseeUserFunction_UserId]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_LicenseeUserFunction_FunctionId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LicenseeUserFunctions] DROP CONSTRAINT [DF_LicenseeUserFunction_FunctionId]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_LicenseeUserFunctions_LicenseeId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LicenseeUserFunctions] DROP CONSTRAINT [DF_LicenseeUserFunctions_LicenseeId]
END

GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[LicenseeUserFunctions]    Script Date: 12/12/2011 16:04:09 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LicenseeUserFunctions]') AND type in (N'U'))
DROP TABLE [dbo].[LicenseeUserFunctions]
GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[LicenseeUserFunctions]    Script Date: 12/12/2011 16:04:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LicenseeUserFunctions](
	[UserFuncionId] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[FunctionId] [int] NOT NULL,
	[LicenseeId] [int] NOT NULL,
 CONSTRAINT [PK_LicenseeUserFunction] PRIMARY KEY CLUSTERED 
(
	[UserFuncionId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [Licensee_table]
) ON [Licensee_table]

GO

ALTER TABLE [dbo].[LicenseeUserFunctions] ADD  CONSTRAINT [DF_LicenseeUserFunction_UserId]  DEFAULT ((0)) FOR [UserId]
GO

ALTER TABLE [dbo].[LicenseeUserFunctions] ADD  CONSTRAINT [DF_LicenseeUserFunction_FunctionId]  DEFAULT ((0)) FOR [FunctionId]
GO

ALTER TABLE [dbo].[LicenseeUserFunctions] ADD  CONSTRAINT [DF_LicenseeUserFunctions_LicenseeId]  DEFAULT ((0)) FOR [LicenseeId]
GO

GRANT SELECT ON [dbo].[LicenseeUserFunctions] TO [bodbLicenseeNet] 

GO
