USE bodb02
GO

/*
	Created: 20170504@Harper
	Description: #76026: 12bet - Integrate 12Amber

	Run on dbpro/dbtrans
*/

--RUN ON DBPRO
--insert data for bettype table
IF NOT EXISTS (SELECT 1 FROM dbo.bettype WITH (NOLOCK) WHERE typeid = 22026)
BEGIN
	INSERT INTO dbo.bettype ( typeid , typenamee , typenamec , typedesc , typenamec_uni , ParentTypeid )
	VALUES (22026, 'DTRA12Amber', 'DTRA12Amber', '12Amber Transfer', 'DTRA12Amber', 22026)
END

IF NOT EXISTS (SELECT 1 FROM dbo.bettype WITH (NOLOCK) WHERE typeid = 22027)
BEGIN
	INSERT INTO dbo.bettype (typeid, typenamee, typenamec, typedesc, typenamec_uni, ParentTypeid)
	VALUES (22027, 'DCAN12Amber', 'DCAN12Amber', '12Amber Cancel Transfer', 'DCAN12Amber', 22027)	
END


--RUN ON DBTRANS
--insert data for ThirdPartySetting table
IF NOT EXISTS (SELECT 1 FROM dbo.ThirdPartySetting WITH (NOLOCK) WHERE ThirdPartyType = 10)
BEGIN
    INSERT INTO dbo.ThirdPartySetting (ThirdPartyType, ThirdPartyName, TransferBettype, CancelBettype)           
    VALUES  ( 10 , '12Amber' , 22026 , 22027 )
END

GO

