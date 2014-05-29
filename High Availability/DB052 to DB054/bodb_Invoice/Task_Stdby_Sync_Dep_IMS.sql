IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_Stdby_Sync_Dep_IMS]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Task_Stdby_Sync_Dep_IMS]
GO

CREATE PROCEDURE [dbo].[Task_Stdby_Sync_Dep_IMS]
AS
/*
Created	: 20140529@Don
Task	: IMS - Sync data 
DB		: DB054.bodb_Invoice

Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServCurrent SYSNAME	= ''
	DECLARE @ServRemote SYSNAME		= ''
 
	SELECT @ServCurrent = @@SERVERNAME
	SELECT @ServRemote  = (SELECT sn FROM OPENQUERY(DBLIC,'SELECT @@SERVERNAME sn'))

	IF @@ERROR != 0
		RETURN

	IF ISNULL(@ServCurrent, '') = ISNULL(@ServRemote, '')
		RETURN

	/* Sync data */
	TRUNCATE TABLE bodb_Invoice.dbo.InvoiceItems
	SET IDENTITY_INSERT bodb_Invoice.dbo.InvoiceItems ON
	INSERT INTO bodb_Invoice.dbo.InvoiceItems(InvoiceItemID,InvoiceID,Description,Reference,Amount,ItemType,InvoiceMonth,DiscountItem)
	SELECT InvoiceItemID,InvoiceID,Description,Reference,Amount,ItemType,InvoiceMonth,DiscountItem FROM DBLIC.bodb_Invoice.dbo.InvoiceItems WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Invoice.dbo.InvoiceItems OFF
	---------------------------
	TRUNCATE TABLE bodb_Invoice.dbo.InvoiceProduct

	INSERT INTO bodb_Invoice.dbo.InvoiceProduct(InvoiceID,ProductID)
	SELECT InvoiceID,ProductID FROM DBLIC.bodb_Invoice.dbo.InvoiceProduct WITH(NOLOCK)

	---------------------------
	TRUNCATE TABLE bodb_Invoice.dbo.Invoices
	SET IDENTITY_INSERT bodb_Invoice.dbo.Invoices ON
	INSERT INTO bodb_Invoice.dbo.Invoices(InvoiceID,InvoiceNo,InvoiceName,PartyID,LicenseeID,InvoiceType,Currency,FromDate,ToDate,DueDate,TotalAmount,IsDeleted,Note)
	SELECT InvoiceID,InvoiceNo,InvoiceName,PartyID,LicenseeID,InvoiceType,Currency,FromDate,ToDate,DueDate,TotalAmount,IsDeleted,Note FROM DBLIC.bodb_Invoice.dbo.Invoices WITH(NOLOCK)
	SET IDENTITY_INSERT bodb_Invoice.dbo.Invoices OFF
	---------------------------	

END



GO
GRANT VIEW DEFINITION ON [dbo].[Task_Stdby_Sync_Dep_IMS] TO [vnteam]