/* Create Table LrfDomain */ 
CREATE TABLE [dbo].[LrfDomain](
	[Id] [int] NOT NULL,
	[DomainName] [varchar](200) NOT NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_LrfDomain] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [Licensee_table]
) ON [Licensee_table]
GO
SET ANSI_PADDING OFF
GO
INSERT [dbo].[LrfDomain] ([Id], [DomainName], [IsActive]) VALUES (1, N'203.160.236.150/LRF1', 1)
INSERT [dbo].[LrfDomain] ([Id], [DomainName], [IsActive]) VALUES (2, N'203.160.236.150/LRF2', 1)
/****** Object:  Default [DF_LrfDomain_Domain]    Script Date: 11/30/2012 15:42:36 ******/
ALTER TABLE [dbo].[LrfDomain] ADD  CONSTRAINT [DF_LrfDomain_Domain]  DEFAULT ('') FOR [DomainName]
GO
/****** Object:  Default [DF_LrfDomain_IsActive]    Script Date: 11/30/2012 15:42:36 ******/
ALTER TABLE [dbo].[LrfDomain] ADD  CONSTRAINT [DF_LrfDomain_IsActive]  DEFAULT ((0)) FOR [IsActive]
GO

