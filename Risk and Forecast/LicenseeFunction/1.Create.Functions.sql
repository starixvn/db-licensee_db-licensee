USE [bodb_Licensee]
GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_Name]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_Name]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_Description]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_Description]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_ParentId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_ParentId]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_Url]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_Url]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_IsMenu]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_IsMenu]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_IsActive]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_DisplayOrder]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_DisplayOrder]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_Functions_IsNew]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Functions] DROP CONSTRAINT [DF_Functions_IsNew]
END

GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[Functions]    Script Date: 12/12/2011 16:03:38 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Functions]') AND type in (N'U'))
DROP TABLE [dbo].[Functions]
GO

USE [bodb_Licensee]
GO

/****** Object:  Table [dbo].[Functions]    Script Date: 12/12/2011 16:03:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[Functions](
	[FunctionId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](4000) NOT NULL,
	[ParentId] [int] NOT NULL,
	[Url] [varchar](200) NOT NULL,
	[IsMenu] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsNew] [bit] NOT NULL,
 CONSTRAINT [PK_Functions] PRIMARY KEY CLUSTERED 
(
	[FunctionId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [Licensee_table]
) ON [Licensee_table]

GO

SET ANSI_PADDING OFF
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_Name]  DEFAULT (N'') FOR [Name]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_Description]  DEFAULT (N'') FOR [Description]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_ParentId]  DEFAULT ((0)) FOR [ParentId]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_Url]  DEFAULT ('') FOR [Url]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_IsMenu]  DEFAULT ((0)) FOR [IsMenu]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_DisplayOrder]  DEFAULT ((0)) FOR [DisplayOrder]
GO

ALTER TABLE [dbo].[Functions] ADD  CONSTRAINT [DF_Functions_IsNew]  DEFAULT ((0)) FOR [IsNew]
GO

GRANT SELECT ON [dbo].[Functions] TO [bodbLicenseeNet] 

GO