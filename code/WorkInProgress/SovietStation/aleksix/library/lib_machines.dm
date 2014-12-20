/* Library Machines
 *
 * Contains:
 *		Borrowbook datum
 *		Library Public Computer
 *		Library Computer
 *		Library Scanner
 *		Book Binder
 */

/*
 * Borrowbook datum
 */
datum/borrowbook // Datum used to keep track of who has borrowed what when and for how long.
	var/bookname
	var/mobname
	var/getdate
	var/duedate

/*
 * Book_entry datum
 */
datum/book_entry	//Used to keep track of every book
	var/uploader
	var/title
	var/author
	var/contents
	var/category
	var/id			//Not really useful,but fail-safe

var/global/list/book_db=list()				//The database itself
var/global/list/toshow=list()		//All the settings
//Sadly,these must be global

/*
 * Library Public Computer
 */
/obj/machinery/librarypubliccomp
	name = "visitor computer"
	icon = 'icons/obj/library.dmi'
	icon_state = "computer"
	anchored = 1
	density = 1
	var/screenstate = 0
	var/title=""	//Any title
	var/category = "Any"
	var/author=""	//Any author

/obj/machinery/librarypubliccomp/attack_hand(var/mob/user as mob)
	usr.set_machine(src)
	var/dat = "<HEAD><TITLE>Library Visitor</TITLE></HEAD><BODY>\n" // <META HTTP-EQUIV='Refresh' CONTENT='10'>
	switch(screenstate)
		if(0)
			dat += "<h2>Search Settings</h2><br>"
			dat += "<A href='?src=\ref[src];settitle=1'>Filter by Title: [title]</A><BR>"
			dat += "<A href='?src=\ref[src];setcategory=1'>Filter by Category: [category]</A><BR>"
			dat += "<A href='?src=\ref[src];setauthor=1'>Filter by Author: [author]</A><BR>"
			dat += "<A href='?src=\ref[src];search=1'>\[Start Search\]</A><BR>"
		if(1)
			if (book_db.len==0)
				dat += "<font color=red><b>ERROR</b>: External Archive is empty.</font><BR>"
			else
				dat += "<table>"
				dat += "<tr><td>AUTHOR</td><td>TITLE</td><td>CATEGORY</td><td>SS<sup>13</sup>BN</td></tr>"

				for(var/datum/book_entry/newbook in toshow)
					var/title = newbook.title
					var/author = newbook.author
					var/category = newbook.category
					var/id = newbook.id

					dat += "<tr><td>[author]</td><td>[title]</td><td>[category]</td><td>[id]</td></tr>"
				dat += "</table><BR>"
			dat += "<A href='?src=\ref[src];back=1'>\[Go Back\]</A><BR>"
	user << browse(dat, "window=publiclibrary")
	onclose(user, "publiclibrary")

/obj/machinery/librarypubliccomp/Topic(href, href_list)
	if(..())
		usr << browse(null, "window=publiclibrary")
		onclose(usr, "publiclibrary")
		return

	if(href_list["settitle"])
		var/newtitle = input("Enter a title to search for:") as text|null
		if(newtitle)
			title = newtitle	//Sanitize doesn't work for Cyrillics
		else
			title = ""
	if(href_list["setcategory"])
		var/newcategory = input("Choose a category to search for:") in list("Any", "Fiction", "Non-Fiction", "Adult", "Reference", "Religion")
		if(newcategory)			//category = sanitize(newcategory)	//Doesn't make sense.Categories are pre-defined
			category = newcategory
		else
			category = "Any"
	if(href_list["setauthor"])
		var/newauthor = input("Enter an author to search for:") as text|null
		if(newauthor)
			author = newauthor
		else
			author = ""
	if(href_list["search"])
		toshow=list()
		if(category == "Any")
			for(var/datum/book_entry/newbook in book_db)
				if(findtext(newbook.author,author)>0 && findtext(newbook.title,title)>0)	//Check if our book variables CONTAIN these
					toshow+=newbook
		else
			for(var/datum/book_entry/newbook in book_db)
				if(findtext(newbook.author,author)>0 && findtext(newbook.title,title)>0 && newbook.category==category)	//Categories are pre-defined,so it's meaningless to search for them
					toshow+=newbook
		screenstate = 1

	if(href_list["back"])
		screenstate = 0

	src.add_fingerprint(usr)
	src.updateUsrDialog()
	return


/*
 * Library Computer
 */
// TODO: Make this an actual /obj/machinery/computer that can be crafted from circuit boards and such
// It is August 22nd, 2012... This TODO has already been here for months.. I wonder how long it'll last before someone does something about it.
/obj/machinery/librarycomp
	name = "Check-In/Out Computer"
	icon = 'icons/obj/library.dmi'
	icon_state = "computer"
	anchored = 1
	density = 1
	var/arcanecheckout = 0
	var/screenstate = 0 // 0 - Main Menu, 1 - Inventory, 2 - Checked Out, 3 - Check Out a Book
	var/buffer_book
	var/buffer_mob
	var/upload_category = "Fiction"
	var/list/checkouts = list()
	var/list/inventory = list()
	var/checkoutperiod = 5 // In minutes
	var/obj/machinery/libraryscanner/scanner // Book scanner that will be used when uploading books to the Archive

	var/bibledelay = 0 // LOL NO SPAM (1 minute delay) -- Doohl

/obj/machinery/librarycomp/proc/update_data()
	book_db=list()		//We have to deal with multiple computers,so only the last one will actualy update the database
	toshow=list()
	var/book_ids=new/savefile("libbooks/ids.sav")
	var/ids
	book_ids["id"]>>ids
	if(ids!=null && ids>0)
		for(var/c=1,c<=ids,c++)
			var/datum/book_entry/newbook=new()
			var/book=new/savefile("libbooks/books/[c]_book.sav")
			newbook.uploader=book["uploader"]
			newbook.author=book["author"]
			newbook.title=book["title"]
			newbook.category=book["cat"]
			newbook.contents=book["contents"]
			newbook.id=c
			book_db+=newbook
		toshow=book_db.Copy()
	else
		book_ids["id"]<<0

/obj/machinery/librarycomp/New()
	..()
	update_data()

/obj/machinery/librarycomp/proc/add_book(author,title,category,contents,uploader)
	var/book=new/savefile("libbooks/books/[book_db.len+1]_book.sav")
	var/datum/book_entry/newbook=new()
	newbook.uploader=uploader
	newbook.author=author
	newbook.title=title
	newbook.category=category
	newbook.contents=contents
	newbook.id=book_db.len+1
	book["uploader"]=uploader
	book["author"]=author
	book["title"]=title
	book["cat"]=category
	book["contents"]=contents
	//var/list/newbook=list(uploader,title,author,category,contents)
	//book_db+=newbook
	book_db+=newbook
	var/book_ids=new/savefile("libbooks/ids.sav")
	book_ids["id"]<<book_db.len
	/*
	book_db+=list()
	book_db[book_db.len][1]=uploader
	book_db[book_db.len][2]=title
	book_db[book_db.len][3]=author
	book_db[book_db.len][4]=category
	book_db[book_db.len][5]=contents
	*/

/obj/machinery/librarycomp/attack_hand(var/mob/user as mob)
	usr.set_machine(src)
	var/dat = "<HEAD><TITLE>Book Inventory Management</TITLE></HEAD><BODY>\n" // <META HTTP-EQUIV='Refresh' CONTENT='10'>
	switch(screenstate)
		if(0)
			// Main Menu
			dat += "<A href='?src=\ref[src];switchscreen=1'>1. View General Inventory</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=2'>2. View Checked Out Inventory</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=3'>3. Check out a Book</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=4'>4. Connect to External Archive</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=5'>5. Upload New Title to Archive</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=6'>6. Print a Bible</A><BR>"
			if(src.emagged)
				dat += "<A href='?src=\ref[src];switchscreen=7'>7. Access the Forbidden Lore Vault</A><BR>"
			if(src.arcanecheckout)
				new /obj/item/weapon/book/tome(src.loc)
				user << "<span class='warning'>Your sanity barely endures the seconds spent in the vault's browsing window. The only thing to remind you of this when you stop browsing is a dusty old tome sitting on the desk. You don't really remember printing it.</span>"
				user.visible_message("[user] stares at the blank screen for a few moments, his expression frozen in fear. When he finally awakens from it, he looks a lot older.", 2)
				src.arcanecheckout = 0
		if(1)
			// Inventory
			dat += "<H3>Inventory</H3><BR>"
			for(var/obj/item/weapon/book/b in inventory)
				dat += "[b.name] <A href='?src=\ref[src];delbook=\ref[b]'>(Delete)</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(2)
			// Checked Out
			dat += "<h3>Checked Out Books</h3><BR>"
			for(var/datum/borrowbook/b in checkouts)
				var/timetaken = world.time - b.getdate
				//timetaken *= 10
				timetaken /= 600
				timetaken = round(timetaken)
				var/timedue = b.duedate - world.time
				//timedue *= 10
				timedue /= 600
				if(timedue <= 0)
					timedue = "<font color=red><b>(OVERDUE)</b> [timedue]</font>"
				else
					timedue = round(timedue)
				dat += "\"[b.bookname]\", Checked out to: [b.mobname]<BR>--- Taken: [timetaken] minutes ago, Due: in [timedue] minutes<BR>"
				dat += "<A href='?src=\ref[src];checkin=\ref[b]'>(Check In)</A><BR><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(3)
			// Check Out a Book
			dat += "<h3>Check Out a Book</h3><BR>"
			dat += "Book: [src.buffer_book] "
			dat += "<A href='?src=\ref[src];editbook=1'>\[Edit\]</A><BR>"
			dat += "Recipient: [src.buffer_mob] "
			dat += "<A href='?src=\ref[src];editmob=1'>\[Edit\]</A><BR>"
			dat += "Checkout Date : [world.time/600]<BR>"
			dat += "Due Date: [(world.time + checkoutperiod)/600]<BR>"
			dat += "(Checkout Period: [checkoutperiod] minutes) (<A href='?src=\ref[src];increasetime=1'>+</A>/<A href='?src=\ref[src];decreasetime=1'>-</A>)"
			dat += "<A href='?src=\ref[src];checkout=1'>(Commit Entry)</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(4)
			dat += "<h3>External Archive</h3>"
			if(book_db.len>0)
				dat += "<A href='?src=\ref[src];orderbyid=1'>(Order book by SS<sup>13</sup>BN)</A><BR><BR>"
				dat += "<table>"
				dat += "<tr><td>AUTHOR</td><td>TITLE</td><td>CATEGORY</td><td></td></tr>"

				for(var/datum/book_entry/b in book_db)
					var/title = b.title
					var/author = b.author
					var/category = b.category
					dat += "<tr><td>[author]</td><td>[title]</td><td>[category]</td><td><A href='?src=\ref[src];targetid=[b.id]'>\[Order\]</A></td></tr>"
				dat += "</table>"
			else
				dat += "<font color=red><b>ERROR</b>: External Archive is empty.</font>"
			dat += "<BR><A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(5)
			dat += "<H3>Upload a New Title</H3>"
			if(!scanner)
				for(var/obj/machinery/libraryscanner/S in range(9))
					scanner = S
					break
			if(!scanner)
				dat += "<FONT color=red>No scanner found within wireless network range.</FONT><BR>"
			else if(!scanner.cache)
				dat += "<FONT color=red>No data found in scanner memory.</FONT><BR>"
			else
				dat += "<TT>Data marked for upload...</TT><BR>"
				dat += "<TT>Title: </TT>[scanner.cache.name]<BR>"
				if(!scanner.cache.author)
					scanner.cache.author = "Anonymous"
				dat += "<TT>Author: </TT><A href='?src=\ref[src];setauthor=1'>[scanner.cache.author]</A><BR>"
				dat += "<TT>Category: </TT><A href='?src=\ref[src];setcategory=1'>[upload_category]</A><BR>"
				dat += "<A href='?src=\ref[src];upload=1'>\[Upload\]</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(7)
			dat += "<h3>Accessing Forbidden Lore Vault v 1.3</h3>"
			dat += "Are you absolutely sure you want to proceed? EldritchTomes Inc. takes no responsibilities for loss of sanity resulting from this action.<p>"
			dat += "<A href='?src=\ref[src];arccheckout=1'>Yes.</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>No.</A><BR>"

	//dat += "<A HREF='?src=\ref[user];mach_close=library'>Close</A><br><br>"
	user << browse(dat, "window=library")
	onclose(user, "library")

/obj/machinery/librarycomp/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (src.density && istype(W, /obj/item/weapon/card/emag))
		src.emagged = 1
	if(istype(W, /obj/item/weapon/barcodescanner))
		var/obj/item/weapon/barcodescanner/scanner = W
		scanner.computer = src
		user << "[scanner]'s associated machine has been set to [src]."
		for (var/mob/V in hearers(src))
			V.show_message("[src] lets out a low, short blip.", 2)
	else
		..()

/obj/machinery/librarycomp/Topic(href, href_list)
	if(..())
		usr << browse(null, "window=library")
		onclose(usr, "library")
		return

	if(href_list["switchscreen"])
		switch(href_list["switchscreen"])
			if("0")
				screenstate = 0
			if("1")
				screenstate = 1
			if("2")
				screenstate = 2
			if("3")
				screenstate = 3
			if("4")
				screenstate = 4
			if("5")
				screenstate = 5
			if("6")
				if(!bibledelay)

					var/obj/item/weapon/storage/bible/B = new /obj/item/weapon/storage/bible(src.loc)
					if(ticker && ( ticker.Bible_icon_state && ticker.Bible_item_state) )
						B.icon_state = ticker.Bible_icon_state
						B.item_state = ticker.Bible_item_state
						B.name = ticker.Bible_name
						B.deity_name = ticker.Bible_deity_name

					bibledelay = 1
					spawn(60)
						bibledelay = 0

				else
					for (var/mob/V in hearers(src))
						V.show_message("<b>[src]</b>'s monitor flashes, \"Bible printer currently unavailable, please wait a moment.\"")

			if("7")
				screenstate = 7
	if(href_list["arccheckout"])
		if(src.emagged)
			src.arcanecheckout = 1
		src.screenstate = 0
	if(href_list["increasetime"])
		checkoutperiod += 1
	if(href_list["decreasetime"])
		checkoutperiod -= 1
		if(checkoutperiod < 1)
			checkoutperiod = 1
	if(href_list["editbook"])
		buffer_book = copytext(sanitize(input("Enter the book's title:") as text|null),1,MAX_MESSAGE_LEN)
	if(href_list["editmob"])
		buffer_mob = copytext(sanitize(input("Enter the recipient's name:") as text|null),1,MAX_NAME_LEN)
	if(href_list["checkout"])
		var/datum/borrowbook/b = new /datum/borrowbook
		b.bookname = sanitize(buffer_book)
		b.mobname = sanitize(buffer_mob)
		b.getdate = world.time
		b.duedate = world.time + (checkoutperiod * 600)
		checkouts.Add(b)
	if(href_list["checkin"])
		var/datum/borrowbook/b = locate(href_list["checkin"])
		checkouts.Remove(b)
	if(href_list["delbook"])
		var/obj/item/weapon/book/b = locate(href_list["delbook"])
		inventory.Remove(b)
	if(href_list["setauthor"])
		var/newauthor = copytext(sanitize(input("Enter the author's name: ") as text|null),1,MAX_MESSAGE_LEN)
		if(newauthor)
			scanner.cache.author = newauthor
	if(href_list["setcategory"])
		var/newcategory = input("Choose a category: ") in list("Fiction", "Non-Fiction", "Adult", "Reference", "Religion")
		if(newcategory)
			upload_category = newcategory
	if(href_list["upload"])
		if(scanner)
			if(scanner.cache)
				var/choice = input("Are you certain you wish to upload this title to the Archive?") in list("Confirm", "Abort")
				if(choice == "Confirm")
					add_book(scanner.cache.author,scanner.cache.name,upload_category,scanner.cache.dat,usr.key)
					log_game("[usr.name]/[usr.key] has uploaded the book titled [scanner.cache.name], [length(scanner.cache.dat)] signs")
					alert("Upload Complete.")
	if(href_list["targetid"])
		if(bibledelay)
			for (var/mob/V in hearers(src))
				V.show_message("<b>[src]</b>'s monitor flashes, \"Printer unavailable. Please allow a short time before attempting to print.\"")
		else
			bibledelay = 1
			spawn(60)
				bibledelay = 0
			var/id=text2num(href_list["targetid"])
			var/datum/book_entry/newbook=book_db[id]
			var/obj/item/weapon/book/B = new(src.loc)
			B.name = "[newbook.title]"
			B.title = newbook.title
			B.author = newbook.author
			B.dat =	newbook.contents
			B.icon_state = "book[rand(1,7)]"
			src.visible_message("[src]'s printer hums as it produces a completely bound book. How did it do that?")
					//break
	if(href_list["orderbyid"])
		var/orderid = input("Enter your order:") as num|null
		if(orderid)
			if(isnum(orderid))
				var/nhref = "src=\ref[src];targetid=[orderid]"
				spawn() src.Topic(nhref, params2list(nhref), src)
	src.add_fingerprint(usr)
	src.updateUsrDialog()
	return

/*
 * Library Scanner
 */
/obj/machinery/libraryscanner
	name = "scanner"
	icon = 'icons/obj/library.dmi'
	icon_state = "bigscanner"
	anchored = 1
	density = 1
	var/obj/item/weapon/book/cache		// Last scanned book
	var/loaded = 0

/obj/machinery/libraryscanner/attackby(var/obj/O as obj, var/mob/user as mob)
	if(istype(O, /obj/item/weapon/book))
		if(loaded == 0)
			user.drop_item()
			O.loc = src
			loaded = 1
		else
			user<<"<font color=red>There is a book already</font>"

/obj/machinery/libraryscanner/attack_hand(var/mob/user as mob)
	usr.set_machine(src)
	var/dat = "<HEAD><TITLE>Scanner Control Interface</TITLE></HEAD><BODY>\n" // <META HTTP-EQUIV='Refresh' CONTENT='10'>
	if(cache)
		dat += "<FONT color=#005500>Data stored in memory.</FONT><BR>"
	else
		dat += "No data stored in memory.<BR>"
	dat += "<A href='?src=\ref[src];scan=1'>\[Scan\]</A>"
	if(cache)
		dat += "       <A href='?src=\ref[src];clear=1'>\[Clear Memory\]</A><BR><BR><A href='?src=\ref[src];eject=1'>\[Remove Book\]</A>"
	else
		dat += "<BR>"
	user << browse(dat, "window=scanner")
	onclose(user, "scanner")

/obj/machinery/libraryscanner/Topic(href, href_list)
	if(..())
		usr << browse(null, "window=scanner")
		onclose(usr, "scanner")
		return

	if(href_list["scan"])
		for(var/obj/item/weapon/book/B in contents)
			cache = B
			break
	if(href_list["clear"])
		cache = null
	if(href_list["eject"])
		for(var/obj/item/weapon/book/B in contents)
			B.loc = src.loc
			loaded = 0
	src.add_fingerprint(usr)
	src.updateUsrDialog()
	return


/*
 * Book binder
 */
/obj/machinery/bookbinder
	name = "Book Binder"
	icon = 'icons/obj/library.dmi'
	icon_state = "binder"
	anchored = 1
	density = 1

/obj/machinery/bookbinder/attackby(var/obj/O as obj, var/mob/user as mob)
	if(istype(O, /obj/item/weapon/paper))
		user.drop_item()
		O.loc = src
		user.visible_message("[user] loads some paper into [src].", "You load some paper into [src].")
		src.visible_message("[src] begins to hum as it warms up its printing drums.")
		sleep(rand(200,400))
		src.visible_message("[src] whirs as it prints and binds a new book.")
		var/obj/item/weapon/book/b = new(src.loc)
		b.dat = O:info
		b.name = "Print Job #" + "[rand(100, 999)]"
		b.icon_state = "book[rand(1,7)]"
		del(O)
	else
		..()